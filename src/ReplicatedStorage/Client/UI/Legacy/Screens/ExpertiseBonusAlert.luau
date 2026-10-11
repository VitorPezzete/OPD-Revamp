--!strict
--[[
	"Sam's Quest Progress Bonus!" line shown every time a stage of an Expertise mission is
	finished: an amber line in the middle of the screen, a little above mid-height, that
	stays three seconds, fades and is removed. Several in a row stack under each other,
	four at most (the legacy copies were all drawn on the same spot).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_TIME = 3
local FADE = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
local REMOVE_AFTER = 1
local MAX_ALERTS = 4

-- The old line on a 1920x1080 screen; the first one is centred where the old one was.
local LINE_SIZE = Vector2.new(408, 32)
local AMBER = Color3.fromRGB(255, 191, 0)

type Alert = { Id: number }

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		-- Oldest first. The records keep their identity, so a line is built once.
		local alerts: Fusion.Value<{ Alert }> = scope:Value({})
		local count = 0
		local alive = true

		local connection = Knit.GetService("ExpertiseService").StageCompleted:Connect(function()
			count += 1
			local alert: Alert = { Id = count }
			local list = table.clone(Fusion.peek(alerts))
			table.insert(list, alert)
			-- Newer ones push the oldest out.
			while #list > MAX_ALERTS do
				table.remove(list, 1)
			end
			alerts:set(list)

			task.delay(HOLD_TIME + REMOVE_AFTER, function()
				if not alive then
					return
				end
				local kept: { Alert } = {}
				for _, other in Fusion.peek(alerts) do
					if other ~= alert then
						table.insert(kept, other)
					end
				end
				alerts:set(kept)
			end)
		end)
		table.insert(scope, function()
			alive = false
			connection:Disconnect()
		end)

		local lines = scope:ForValues(alerts, function(_use, lineScope: Scope, alert: Alert)
			local leaving = lineScope:Value(false)
			local ended = false
			table.insert(lineScope, function()
				ended = true
			end)
			task.delay(HOLD_TIME, function()
				if not ended then
					leaving:set(true)
				end
			end)

			return Kit.Label(lineScope, {
				Name = "Alert",
				Text = "Sam's Quest Progress Bonus!",
				TextSize = Kit.TextSize.Heading,
				Color = AMBER,
				Fit = true,
				Size = UDim2.fromOffset(LINE_SIZE.X, LINE_SIZE.Y),
				LayoutOrder = alert.Id,
				Transparency = lineScope:Tween(
					lineScope:Computed(function(use): number
						return if use(leaving) then 1 else 0
					end),
					FADE
				),
			})
		end)

		return Kit.Screen(scope, {
			Name = "ExpertiseBonusAlert",
			-- Over the HUD, like the rework's.
			DisplayOrder = 40,
			Children = {
				Kit.Stack(scope, {
					Name = "Alerts",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.4, -LINE_SIZE.Y / 2),
					Size = UDim2.fromOffset(LINE_SIZE.X, LINE_SIZE.Y * MAX_ALERTS),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = lines,
				}),
			},
		})
	end,
}
