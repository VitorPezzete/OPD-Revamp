--!strict
--[[
	Raid place only: the black cover that hides the world while the party loads in
	("Waiting for players to load... 2/4"). Up while RaidRunService reports the Waiting
	phase, gone the moment the raid starts and the characters are spawned.

	Everything shown is read from the Workspace attributes of RaidStateConfig; the client
	sends nothing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local RaidStateConfig = require(ReplicatedStorage.Shared.Configs.RaidStateConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local ATTRIBUTES = RaidStateConfig.Attributes
local FADE = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Seconds between two dots of "Waiting for players to load...".
local DOT_INTERVAL = 0.5
local MAX_DOTS = 3

return {
	-- Mounted in the raid place only; elsewhere nothing ever opens it.
	Persistent = PlaceConfig.Role == "Raid",

	Mount = function(scope: Scope, _gui: any, _context: any)
		local phase = Bind.attribute(scope, Workspace, ATTRIBUTES.Phase, "Waiting")
		local arrived = Bind.attribute(scope, Workspace, ATTRIBUTES.Arrived, 0)
		local expected = Bind.attribute(scope, Workspace, ATTRIBUTES.Expected, 0)
		local dots = scope:Value(0)

		local waiting = scope:Computed(function(use): boolean
			return use(phase) == "Waiting"
		end)
		local fade = scope:Tween(
			scope:Computed(function(use): number
				return if use(waiting) then 0 else 1
			end),
			FADE
		)

		-- Runs only while the cover is up.
		local alive = true
		local function animate()
			while alive and Fusion.peek(waiting) do
				dots:set((Fusion.peek(dots) + 1) % (MAX_DOTS + 1))
				task.wait(DOT_INTERVAL)
			end
		end
		scope:Observer(waiting):onChange(function()
			if Fusion.peek(waiting) then
				task.spawn(animate)
			end
		end)
		if Fusion.peek(waiting) then
			task.spawn(animate)
		end
		table.insert(scope, function()
			alive = false
		end)

		return UI.Screen(scope, {
			Name = "RaidWaiting",
			DisplayOrder = 50,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Cover",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.Black,
					BackgroundTransparency = fade,
					BorderSizePixel = 0,
					-- Swallows clicks while it hides the world.
					Active = waiting,
					Visible = scope:Computed(function(use): boolean
						return use(fade) < 1
					end),
					[Fusion.Children] = {
						UI.Label(scope, {
							Name = "Status",
							Text = scope:Computed(function(use): string
								return "Waiting for players to load" .. string.rep(".", use(dots))
							end),
							Variant = "Title",
							Transparency = fade,
							-- Left aligned in a fixed box, so the dots do not shift the sentence.
							TextXAlignment = Enum.TextXAlignment.Left,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.42),
							Size = UDim2.fromOffset(470, 44),
						}),
						UI.Label(scope, {
							Name = "Counting",
							Text = scope:Computed(function(use): string
								local total = use(expected)
								-- Nobody admitted yet: the party size is not known.
								return if total > 0 then `{use(arrived)}/{total}` else ""
							end),
							Variant = "Display",
							Font = Numerals.Font,
							Transparency = fade,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.52),
						}),
					},
				}),
			},
		})
	end,
}
