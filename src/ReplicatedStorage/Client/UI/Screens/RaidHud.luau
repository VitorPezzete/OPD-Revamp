--!strict
--[[
	Raid place only: the wave and how many enemies are left, at the top of the screen
	("Wave 7" / "12 Enemies Left"). Shown from the first wave until the raid ends.

	Both numbers are Workspace attributes written by RaidRunService (RaidStateConfig):
	nothing is counted on the client.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local RaidStateConfig = require(ReplicatedStorage.Shared.Configs.RaidStateConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local ATTRIBUTES = RaidStateConfig.Attributes
local SIZE = UDim2.fromOffset(360, 96)
--[[
	Under everything UI.Screens.HealthBar may draw at the top centre: the health bar, the
	haki bar and its two rows of status icons, which end 130 pixels from the top of the
	screen (8 + 28 + 10 + 2 * 36 + 3 * 4). Measured from the same edge as that screen
	(IgnoreGuiInset): at 14 pixels under the top bar the texts lay over the status icons.
]]
local POSITION = UDim2.new(0.5, 0, 0, 138)
-- The texts are drawn straight over the world: white, with a black edge.
local TEXT_OUTLINE = 1.5

return {
	-- Mounted in the raid place only; elsewhere nothing ever opens it.
	Persistent = PlaceConfig.Role == "Raid",

	Mount = function(scope: Scope, _gui: any, _context: any)
		local phase = Bind.attribute(scope, Workspace, ATTRIBUTES.Phase, "Waiting")
		local wave = Bind.attribute(scope, Workspace, ATTRIBUTES.Wave, 0)
		local enemies = Bind.attribute(scope, Workspace, ATTRIBUTES.Enemies, 0)

		return UI.Screen(scope, {
			Name = "RaidHud",
			DisplayOrder = 2,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Raid",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = POSITION,
					Size = SIZE,
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(phase) == "Running" and use(wave) > 0
					end),
					[Fusion.Children] = {
						UI.Stack(scope, {
							Name = "Rows",
							Size = UDim2.fromScale(1, 1),
							Gap = Theme.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							Children = {
								UI.Label(scope, {
									Name = "Wave",
									Text = scope:Computed(function(use): string
										return `Wave {use(wave)}`
									end),
									Variant = "Title",
									Font = Numerals.Font,
									Color = Theme.Colors.White,
									Outline = true,
									OutlineColor = Theme.Colors.Black,
									OutlineThickness = TEXT_OUTLINE,
									OutlineTransparency = 0,
									LayoutOrder = 1,
								}),
								UI.Label(scope, {
									Name = "Enemies",
									Text = scope:Computed(function(use): string
										local count = use(enemies)
										return `{count} {if count == 1 then "Enemy" else "Enemies"} Left`
									end),
									Variant = "Heading",
									Font = Numerals.Font,
									Color = Theme.Colors.White,
									Outline = true,
									OutlineColor = Theme.Colors.Black,
									OutlineThickness = TEXT_OUTLINE,
									OutlineTransparency = 0,
									LayoutOrder = 2,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
