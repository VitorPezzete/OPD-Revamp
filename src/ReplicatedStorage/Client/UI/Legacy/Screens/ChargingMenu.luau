--!strict
--[[
	The charge bars of the old game (StarterGui.ChargingMenu): while an ability is being
	charged, an upright bar at the left edge of the screen fills from the bottom, one bar
	per ability charging, side by side. They stand just above the menu column, their feet
	at half the height of the screen, where the old game had them.

	The old fruit scripts each pushed their own numbers into the bar; here every bar reads
	the one charge state all abilities share (AbilityController: when the charge started
	and how long a full one takes), so any chargeable ability gets one without knowing
	about it. A bar is drawn from the press itself; until the server has said how long the
	charge lasts (the first charge of an ability) it shows empty.

	Legacy interface only (UIConfig.LegacyOnly): the rework shows charges on its ability bar.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

-- The old bar on a 1920x1080 screen: 29 wide, 173 tall, 4 apart, 2.5% in from the left.
local BAR_SIZE = Vector2.new(28, 172)
local BAR_GAP = 4
local LEFT_SHARE = 0.025
local FOOT_SHARE = 0.5
local FRUIT_SLOTS = 2

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local AbilityController = Knit.GetController("AbilityController")

		-- The actions charging right now: a bar exists for each. It only changes when a
		-- charge starts or ends, so bars are not rebuilt while they fill.
		local charging: Fusion.Value<{ [string]: boolean }> = scope:Value({} :: { [string]: boolean })
		-- Action -> how full its bar is (0 to 1), written every frame while it charges.
		local fills: { [string]: Fusion.Value<number> } = {}
		local order: { [string]: number } = {}
		local actions: { string } = {}
		for fruitSlot = 1, FRUIT_SLOTS do
			for abilitySlot = 1, #InputConfig.SlotLetters do
				local action = InputConfig.GetAbilityAction(fruitSlot, abilitySlot)
				table.insert(actions, action)
				order[action] = #actions
				fills[action] = scope:Value(0)
			end
		end

		local stepping: RBXScriptConnection? = nil

		-- Writes the fills and the set of charging actions; true while anything charges.
		local function read(): boolean
			local now = os.clock()
			local current: { [string]: boolean } = {}
			local any, different = false, false
			local before = Fusion.peek(charging)
			for _, action in actions do
				local state = AbilityController:GetState(action)
				if state.ChargeStart then
					any = true
					current[action] = true
					fills[action]:set(
						if state.ChargeSeconds > 0
							then math.clamp((now - state.ChargeStart) / state.ChargeSeconds, 0, 1)
							else 0
					)
				end
				if (current[action] == true) ~= (before[action] == true) then
					different = true
				end
			end
			if different then
				charging:set(current)
			end
			return any
		end

		local function stop()
			if stepping then
				stepping:Disconnect()
				stepping = nil
			end
		end

		-- Only steps while something is charging.
		local function refresh()
			local any = read()
			if any and not stepping then
				stepping = RunService.RenderStepped:Connect(function()
					if not read() then
						stop()
					end
				end)
			elseif not any then
				stop()
			end
		end

		local changed = AbilityController.StateChanged:Connect(refresh)
		table.insert(scope, function()
			changed:Disconnect()
			stop()
		end)
		refresh()

		return Kit.Screen(scope, {
			Name = "ChargingMenu",
			DisplayOrder = 1,
			IgnoreGuiInset = true,
			Children = {
				Kit.Stack(scope, {
					Name = "Table",
					Direction = "Horizontal",
					Gap = BAR_GAP,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(LEFT_SHARE, FOOT_SHARE),
					Children = scope:ForPairs(charging, function(_use, pairScope: Scope, action: string, _on: boolean)
						return action,
							Kit.Bar(pairScope, {
								Name = action,
								Vertical = true,
								Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
								LayoutOrder = order[action],
								Color = Kit.Colors.Charge,
								Value = fills[action],
							})
					end),
				}),
			},
		})
	end,
}
