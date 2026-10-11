--!strict
--[[
	The Yamato box: type a destination and press Enter to open a gate to it.

	Opened and closed by WeaponController while the Yamato is in hand. Only the typed
	name is sent; the server knows the destinations and who may travel (YamatoService).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local MAX_LENGTH = 20
-- Under the health / haki bars of the HUD, where the legacy box sat.
local TOP_MARGIN = 150

return {
	Mount = function(scope: Scope, _gui: any, _context: any)
		local YamatoService = Knit.GetService("YamatoService")
		local typed = scope:Value("")

		return UI.Screen(scope, {
			Name = "YamatoGUI",
			Children = {
				UI.Panel(scope, {
					Name = "MainFrame",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, TOP_MARGIN),
					Size = UDim2.fromOffset(380, 104),
					Color = Theme.Colors.Background,
					Transparency = Theme.Transparency.Hud,
					Stroke = Theme.Colors.BorderStrong,
					Padding = Theme.Space.M,
					Children = {
						UI.Label(scope, {
							Name = "Title",
							Text = "Yamato gate",
							Variant = "Small",
							Color = Theme.Colors.Accent,
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, 22),
						}),
						UI.TextInput(scope, {
							Name = "TextBox",
							Text = typed,
							Placeholder = "Destination, then Enter",
							MaxLength = MAX_LENGTH,
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, 46),
							OnSubmit = function(text: string)
								typed:set("")
								if text ~= "" and #text <= MAX_LENGTH then
									YamatoService:Travel(text):catch(warn)
								end
							end,
						}),
					},
				}),
			},
		})
	end,
}
