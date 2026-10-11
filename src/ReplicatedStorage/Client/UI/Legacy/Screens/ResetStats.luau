--!strict
--[[
	"This action will set all stats back to default" dialog (legacy ResetStats), opened
	from the settings tab with UIController:Toggle("ResetStats").

	The old black box, where it stood (centred, a little above the middle): the warning,
	then RESET and CLOSE side by side. RESET asks the server for the reset and closes;
	CLOSE only closes. What is wiped (and what it costs) is decided by StatResetService;
	the text only repeats it. The old button also had to fire the weapon remote twice to
	fix the loadout afterwards; the server does that itself now.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

-- What StatResetService wipes and keeps today (the old sentence predates it).
local MESSAGE = "This cannot be undone. Your combat stats, Haki, Beri, bounty, kills and fish go back to zero, "
	.. "and your devil fruits and items are removed. Gems, expertise and accessories are kept."

local SIZE = Vector2.new(580, 460)
local PADDING = Kit.Space.XL
local BUTTON_HEIGHT = 84

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local sent = false
		local function close()
			context.Close()
		end

		local buttonWidth = (SIZE.X - 2 * PADDING - Kit.Space.XL) / 2
		-- Named "Window" for the gamepad: the selection on open, and B closes it like CLOSE does.
		local window = Kit.Panel(scope, {
			Name = "Window",
			Image = "",
			Color = Kit.Colors.Sunken,
			Transparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			Padding = PADDING,
			Children = {
				Kit.Label(scope, {
					Name = "Message",
					Text = MESSAGE,
					TextSize = Kit.TextSize.Heading,
					Fit = true,
					Size = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT + Kit.Space.XL)),
				}),
				Kit.Stack(scope, {
					Name = "Buttons",
					Direction = "Horizontal",
					Gap = Kit.Space.XL,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = {
						Kit.Button(scope, {
							Name = "Reset",
							Text = "RESET",
							Variant = "Red",
							TextSize = Kit.TextSize.Title,
							LayoutOrder = 1,
							Size = UDim2.fromOffset(buttonWidth, BUTTON_HEIGHT),
							OnClick = function()
								if sent then
									return
								end
								sent = true
								Knit.GetService("StatResetService"):Reset():catch(warn)
								close()
							end,
						}),
						Kit.Button(scope, {
							Name = "Close",
							Text = "CLOSE",
							Variant = "Grey",
							TextSize = Kit.TextSize.Title,
							LayoutOrder = 2,
							Size = UDim2.fromOffset(buttonWidth, BUTTON_HEIGHT),
							OnClick = close,
						}),
					},
				}),
			},
		})
		Closers.register(scope, window, close)

		return Kit.Screen(scope, {
			Name = "ResetStats",
			-- Opened from the menu, which is still on the screen: above it.
			DisplayOrder = 5,
			Children = window,
		})
	end,
}
