--!strict
--[[
	Turns ability actions into ability inputs. Sends the minimum: fruit slot, ability
	slot, pressed / released and the aim point. The local level check only avoids
	pointless requests; the server repeats every check.

	Which key, gamepad button or touch button triggers DF1A..DF2F is the InputController's
	business; this controller only knows the twelve actions.

	It also keeps what the ability bar draws, per action:
		AbilityController:GetState("DF1B") -> { ReadyAt, ChargeStart, ChargeSeconds }
		AbilityController.StateChanged     (action) after any of it changes
		AbilityController.Pressed          (action) the moment a press is sent
		AbilityController.ChargeEnded      (action) the server ended a charge (released or interrupted)
	Cooldowns and charges come from the server (AbilityService.State). A charge is drawn
	from the press itself, before the server answers, so the bar reacts at once.

	"Tap to Charge" (Settings.Charge_Toggle): for chargeable abilities the first press
	starts the charge and the next press releases it; letting go of the key does nothing.
	On a touch screen whose control layout gives its buttons a behaviour of their own
	("Auto" and "Custom", UI.Util.TouchControls) it only applies to a button left on
	"Hold", which sends the plain press and release the default layout does. The other
	behaviours translate the touches into a press and a release of their own before they
	get here, and two latches would undo each other. ChargeEnded is what lets such a
	button let go when the server ends the charge it was holding.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)

export type AbilityState = {
	-- os.clock() at which the cooldown ends (0 = ready).
	ReadyAt: number,
	-- Length of the cooldown that ends at ReadyAt, for the sweep.
	CooldownSeconds: number,
	-- os.clock() of the press that started the charge being held, nil when none.
	ChargeStart: number?,
	-- Seconds to a full charge (0 = unknown: the bar only pulses).
	ChargeSeconds: number,
}

local PHASE_BEGIN = 1
local PHASE_END = 2
-- A tap-to-charge press the server has not confirmed as a charge by then is dropped
-- (refused press, ability that turned out not to charge).
local LATCH_CONFIRM_SECONDS = 0.6

local AbilityController = Knit.CreateController({
	Name = "AbilityController",
})

AbilityController.StateChanged = Signal.new() :: Signal.Signal<string>
AbilityController.Pressed = Signal.new() :: Signal.Signal<string>
AbilityController.ChargeEnded = Signal.new() :: Signal.Signal<string>

local DataController
local InputController
local SettingsController
local AbilityService

-- Abilities whose press was sent, so a release is only sent for those.
local held: { [string]: boolean } = {}
-- Tap to charge: abilities charging after a press, waiting for the press that releases them.
local latched: { [string]: number } = {}
-- The latch stamp the server confirmed with a "Charge" report.
local confirmed: { [string]: number } = {}
local states: { [string]: AbilityState } = {}
-- Full-charge time last reported per action: a new press draws with it before the server answers.
local knownChargeSeconds: { [string]: number } = {}

local function getState(action: string): AbilityState
	local state = states[action]
	if not state then
		state = { ReadyAt = 0, CooldownSeconds = 0, ChargeStart = nil, ChargeSeconds = 0 }
		states[action] = state
	end
	return state
end

local function getDefinition(fruitSlot: number, abilitySlot: number): FruitConfig.AbilityDefinition?
	local fruitName = DataController:Get(`DevilFruits.Slot{fruitSlot}.Name`)
	return if type(fruitName) == "string" then FruitConfig.GetAbility(fruitName, abilitySlot) else nil
end

local function canUse(fruitSlot: number, abilitySlot: number): boolean
	local definition = getDefinition(fruitSlot, abilitySlot)
	if not definition then
		return false
	end
	return (DataController:Get(`Skills.{definition.Skill}.Level`) or 0) >= definition.Requirement
end

local function isChargeable(action: string, fruitSlot: number, abilitySlot: number): boolean
	local definition = getDefinition(fruitSlot, abilitySlot)
	return (definition ~= nil and definition.Chargeable == true) or knownChargeSeconds[action] ~= nil
end

local function setCharge(action: string, start: number?, seconds: number?)
	local state = getState(action)
	state.ChargeStart = start
	state.ChargeSeconds = seconds or 0
	AbilityController.StateChanged:Fire(action)
end

local function send(action: string, fruitSlot: number, abilitySlot: number, phase: number)
	AbilityService.Input:Fire(fruitSlot, abilitySlot, phase, InputController:GetAimPosition())
end

local function press(action: string, fruitSlot: number, abilitySlot: number)
	held[action] = true
	send(action, fruitSlot, abilitySlot, PHASE_BEGIN)
	AbilityController.Pressed:Fire(action)

	-- Predicted charge: drawn now, corrected (or dropped) by what the server reports.
	local state = getState(action)
	if isChargeable(action, fruitSlot, abilitySlot) and os.clock() >= state.ReadyAt then
		setCharge(action, os.clock(), knownChargeSeconds[action])
	end
end

local function release(action: string, fruitSlot: number, abilitySlot: number)
	held[action] = nil
	latched[action] = nil
	send(action, fruitSlot, abilitySlot, PHASE_END)
	if getState(action).ChargeStart then
		setCharge(action, nil)
	end
end

-- Whether a press of that action latches its charge. A touch button that behaves on its
-- own is left alone, unless that behaviour is the plain hold.
local function tapsToCharge(action: string): boolean
	if SettingsController:Get("Charge_Toggle") ~= true then
		return false
	end
	if InputController:GetDeviceKind() ~= "Touch" then
		return true
	end
	local ok, controls = pcall(Knit.GetController, "ControlsController")
	if not ok or not controls or not controls:UsesBehaviors() then
		return true
	end
	return controls:GetBehavior(action) == "Hold"
end

local function onAction(action: string, fruitSlot: number, abilitySlot: number, phase: string)
	if phase == "Begin" then
		-- Second press of a tap-to-charge ability: it releases.
		if latched[action] then
			release(action, fruitSlot, abilitySlot)
			return
		end
		if not canUse(fruitSlot, abilitySlot) then
			return
		end
		press(action, fruitSlot, abilitySlot)

		if tapsToCharge(action) and isChargeable(action, fruitSlot, abilitySlot) then
			local stamp = os.clock()
			latched[action] = stamp
			task.delay(LATCH_CONFIRM_SECONDS, function()
				-- Still waiting and the server never reported a charge: the press was refused.
				if latched[action] == stamp and confirmed[action] ~= stamp then
					latched[action] = nil
					held[action] = nil
					setCharge(action, nil)
				end
			end)
		end
		return
	end

	-- Letting go of a latched key keeps the charge going.
	if latched[action] then
		return
	end
	if held[action] then
		release(action, fruitSlot, abilitySlot)
	end
end

local function onState(fruitSlot: unknown, abilitySlot: unknown, kind: unknown, seconds: unknown)
	if type(fruitSlot) ~= "number" or type(abilitySlot) ~= "number" or type(seconds) ~= "number" then
		return
	end
	local action = InputConfig.GetAbilityAction(fruitSlot, abilitySlot)
	local state = getState(action)

	if kind == "Cooldown" then
		state.ReadyAt = os.clock() + seconds
		state.CooldownSeconds = seconds
		AbilityController.StateChanged:Fire(action)
	elseif kind == "Charge" then
		knownChargeSeconds[action] = seconds
		if latched[action] then
			confirmed[action] = latched[action]
		end
		-- Keep the predicted start: it is when the key went down.
		setCharge(action, state.ChargeStart or os.clock(), seconds)
	elseif kind == "ChargeEnd" then
		-- Interrupted (stun, death, seal) or released: nothing is charging any more.
		latched[action] = nil
		if state.ChargeStart then
			setCharge(action, nil)
		end
		AbilityController.ChargeEnded:Fire(action)
	end
end

local function resetAll()
	table.clear(latched)
	table.clear(knownChargeSeconds)
	for action, state in states do
		state.ReadyAt = 0
		state.CooldownSeconds = 0
		state.ChargeStart = nil
		state.ChargeSeconds = 0
		AbilityController.StateChanged:Fire(action)
	end
end

function AbilityController:GetState(action: string): AbilityState
	return getState(action)
end

-- Name of the ability on that action for the current fruits, nil when the slot is empty.
function AbilityController:GetDefinition(action: string): FruitConfig.AbilityDefinition?
	local fruitSlot, abilitySlot = string.match(action, "^DF(%d)(%a)$")
	local index = abilitySlot and table.find(InputConfig.SlotLetters, abilitySlot)
	if not fruitSlot or not index then
		return nil
	end
	return getDefinition(tonumber(fruitSlot) :: number, index)
end

function AbilityController:KnitInit()
	DataController = Knit.GetController("DataController")
	InputController = Knit.GetController("InputController")
	SettingsController = Knit.GetController("SettingsController")
end

function AbilityController:KnitStart()
	AbilityService = Knit.GetService("AbilityService")
	AbilityService.State:Connect(onState)

	for fruitSlot = 1, 2 do
		for abilitySlot = 1, #InputConfig.SlotLetters do
			local action = InputConfig.GetAbilityAction(fruitSlot, abilitySlot)
			InputController:OnAction(action, function(phase: string)
				onAction(action, fruitSlot, abilitySlot, phase)
			end)
		end
	end

	-- New fruits: the old cooldowns and charges mean nothing.
	DataController:Observe("DevilFruits.Slot1.Name", resetAll)
	DataController:Observe("DevilFruits.Slot2.Name", resetAll)
	-- Turning the setting off must not leave a charge running with no key to release it.
	SettingsController:Observe("Charge_Toggle", function(value: any)
		if value ~= true then
			for action in table.clone(latched) do
				local fruitSlot, letter = string.match(action, "^DF(%d)(%a)$")
				local index = letter and table.find(InputConfig.SlotLetters, letter)
				if fruitSlot and index then
					release(action, tonumber(fruitSlot) :: number, index)
				end
			end
		end
	end)
end

return AbilityController
