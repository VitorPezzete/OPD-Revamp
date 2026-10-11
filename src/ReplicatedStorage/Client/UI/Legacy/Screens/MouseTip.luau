--!strict
--[[
	Plain text tooltip that follows the mouse (legacy MouseTip): a see-through dark box up
	and to the right of the cursor. Driven by UI.Util.Tooltip: other screens call
	Tooltip.show(text) / Tooltip.hide() instead of reaching into this gui.

	The old box was a quarter of the screen wide whatever it said, its text stretched to
	fill it ("32.5%" in letters 60 pixels tall). The box now wraps its text: one size of
	letters, at most as wide as the old box, growing downwards when the text is long.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local MouseTipFollow = require(ReplicatedStorage.Client.UI.Legacy.Components.MouseTipFollow)

type Scope = Fusion.Scope<typeof(Fusion)>

-- The width of the old box on a 1920x1080 screen.
local MAX_WIDTH = 480
local BOX_COLOR = Color3.fromRGB(35, 35, 35)
local BOX_TRANSPARENCY = 0.45

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local message = Kit.Panel(scope, {
			Name = "Message",
			Image = "",
			Color = BOX_COLOR,
			Transparency = BOX_TRANSPARENCY,
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Padding = Kit.Space.S,
			Visible = scope:Computed(function(use): boolean
				return use(Tooltip.Text) ~= nil
			end),
			Children = {
				Kit.Label(scope, {
					Name = "Text",
					Text = scope:Computed(function(use): string
						return use(Tooltip.Text) or ""
					end),
					TextSize = Kit.TextSize.Body,
					Wrapped = true,
					Children = {
						scope:New("UISizeConstraint")({
							MaxSize = Vector2.new(MAX_WIDTH - 2 * Kit.Space.S, math.huge),
						}),
					},
				}),
			},
		})
		MouseTipFollow.bind(scope, message)

		return Kit.Screen(scope, {
			Name = "MouseTip",
			-- Over every window, like the rework's: a tip belongs to what is under the cursor.
			DisplayOrder = 100,
			Children = { message },
		})
	end,
}
