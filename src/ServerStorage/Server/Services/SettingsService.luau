--!strict
--[[
	The only write path to a player's Settings, and to the Controls table of the "Custom"
	control layout.

		SettingsService.Client:Set(name, value) -> boolean      (client)
		SettingsService.Client:Reset() -> boolean               (client: back to the defaults)
		SettingsService.Client:SetControls(controls) -> boolean (client)
		SettingsService:Get(player, name) -> any                (server: Hitbox, Hit_Counter, ...)
		SettingsService.Changed (player, name, value)

	The legacy remote toggled whatever key it was sent and stored any number as the
	music volume. Here a change is accepted only for a key of SettingsConfig with a
	value of its kind and range; setting a value is idempotent, so a replayed or
	duplicated request cannot flip a toggle back.

	SetControls replaces the whole Controls table (camera and aim offsets, touch buttons;
	ControlsConfig). The client sends it once, when the player saves the editor; sending
	the default table is the reset. What arrives is rebuilt field by field by
	ControlsConfig.Validate - only the known keys and button ids, every number finite and
	inside its range, every behaviour one its button has - and the rebuilt table is what is
	stored: nothing of the client's own table is kept, and anything that is not exactly a
	Controls is refused whole. Nothing on the server reads the table: it only matters to
	the client that owns it, so a bad one could at worst spoil that player's own controls.

	Together they are the touch layout of a player: the preset is the setting
	Control_Layout ("Default", "Auto" or "Custom", through Set like any other setting) and
	the Controls table is what "Custom" applies. Both live in the profile, so they come
	back on every join, in every place that loads this service. The keyboard and gamepad
	layouts are HotkeyService's.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local SettingsConfig = require(ReplicatedStorage.Shared.Configs.SettingsConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type PlayerData = PlayerData.PlayerData

local SettingsService = Knit.CreateService({
	Name = "SettingsService",
	Client = {},
})

SettingsService.Changed = Signal.new() :: Signal.Signal<Player, string, any>

-- Player data only replicates to its owner. Settings other clients must see (the player
-- list hides the bounty of whoever asked for it) are mirrored as player attributes.
local PUBLIC_ATTRIBUTES: { [string]: string } = {
	Hide_Bounty = "HideBounty",
}

local DataService

-- Holding a volume arrow is the only legitimate burst.
local limiter = RateLimiter.new(12, 4)
-- A whole table per request, written when the editor is saved: a few in a row (save,
-- change of mind, reset) and then one every few seconds is all a player needs.
local CONTROLS_BURST = 3
local CONTROLS_PER_SECOND = 0.2
local controlsLimiter = RateLimiter.new(CONTROLS_BURST, CONTROLS_PER_SECOND)
local CONTROLS_PATH = "Controls"
-- A reset is one request; a second one right after changes nothing.
local resetLimiter = RateLimiter.new(2, 0.2)
-- What Reset leaves as it is: which interface is mounted (a choice, not something set
-- wrong, and switching it rebuilds the screen under the button that asked) and the
-- gamepad layout, which belongs to the keybind lists and their own "Defaults".
local RESET_KEEPS: { [string]: boolean } = { UI_Style = true, ControllerType = true }

local function publish(player: Player, name: string, value: any)
	local attribute = PUBLIC_ATTRIBUTES[name]
	if attribute then
		player:SetAttribute(attribute, value)
	end
end

function SettingsService:Get(player: Player, name: string): any
	local definition = SettingsConfig.Definitions[name]
	if not definition then
		return nil
	end

	local data = DataService:GetData(player)
	local value = if data then data:Get(`Settings.{name}`) else nil
	return if value == nil then definition.Default else value
end

function SettingsService.Client:Set(player: Player, name: unknown, value: unknown): boolean
	if not limiter:Consume(player) then
		return false
	end
	if type(name) ~= "string" or not SettingsConfig.IsValid(name, value) then
		return false
	end

	local data: PlayerData? = DataService:GetData(player)
	if not data then
		return false
	end

	data:Set(`Settings.{name}`, value)
	publish(player, name, value)
	SettingsService.Changed:Fire(player, name, value)
	return true
end

--[[
	Every setting back to its default (SettingsConfig), except the ones RESET_KEEPS lists.
	The Controls table is not touched: Control_Layout going back to "Default" stops it
	from being read, and choosing "Custom" again finds it as it was.
]]
function SettingsService.Client:Reset(player: Player): boolean
	if not resetLimiter:Consume(player) then
		return false
	end

	local data: PlayerData? = DataService:GetData(player)
	if not data then
		return false
	end

	for name, definition in SettingsConfig.Definitions do
		if not RESET_KEEPS[name] and data:Get(`Settings.{name}`) ~= definition.Default then
			data:Set(`Settings.{name}`, definition.Default)
			publish(player, name, definition.Default)
			SettingsService.Changed:Fire(player, name, definition.Default)
		end
	end
	return true
end

function SettingsService.Client:SetControls(player: Player, payload: unknown): boolean
	if not controlsLimiter:Consume(player) then
		return false
	end
	-- A new table built from what passed the checks, or nil.
	local controls = ControlsConfig.Validate(payload)
	if not controls then
		return false
	end

	local data: PlayerData? = DataService:GetData(player)
	if not data then
		return false
	end

	data:Set(CONTROLS_PATH, controls)
	return true
end

function SettingsService:KnitInit()
	DataService = Knit.GetService("DataService")
end

function SettingsService:KnitStart()
	DataService:ObserveData(function(player: Player)
		for name in PUBLIC_ATTRIBUTES do
			publish(player, name, SettingsService:Get(player, name))
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
		controlsLimiter:Forget(player)
		resetLimiter:Forget(player)
	end)
end

return SettingsService
