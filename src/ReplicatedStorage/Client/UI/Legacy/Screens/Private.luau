--!strict
--[[
	Private server panel (legacy StarterGui.Private), opened from the spawn screen: the
	old rounded blue box in the middle of the screen, a lighter one inside it, with from
	top to bottom the player's code, Generate, Buy 30 Days, the days left, the box to type
	a code in and Join. "Main Menu" stands above it, at the top of the screen.

	Shows the player's code and days left, and sends three intents: generate a new code,
	buy 30 days, join the server behind a typed code. The server decides everything; the
	code box only carries what the player typed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type Status = { Code: string?, DaysLeft: number }

local CODE_LENGTH = 6
-- Over the spawn screen, like the rework's.
local DISPLAY_ORDER = 30

-- The two blues of the old panel.
local OUTER_COLOR = Color3.fromRGB(73, 138, 234)
local INNER_COLOR = Color3.fromRGB(179, 219, 255)
local CORNER = UDim.new(0, 8)

local PANEL_SIZE = Vector2.new(640, 524)
local INSET = 20
local ROW_WIDTH = UDim.new(1, 0)
local BOX_HEIGHT = 52
local BUTTON_HEIGHT = 60
local LABEL_HEIGHT = 36
local CAPTION_HEIGHT = 22
local MENU_BUTTON_SIZE = UDim2.fromOffset(420, 60)
-- "Main Menu" was a tenth of the way down the screen.
local MENU_BUTTON_Y = 0.1

return {
	-- On a phone the engine's tool bar would be drawn over this window (UIController).
	HidesHotbar = true,

	Mount = function(scope: Scope, _gui: any, context: any)
		local PrivateServerService = Knit.GetService("PrivateServerService")

		local code: Fusion.Value<string?> = scope:Value(nil :: string?)
		local daysLeft = scope:Value(0)
		local typed = scope:Value("")

		local function apply(status: unknown)
			if type(status) == "table" then
				local value = status :: Status
				code:set(if type(value.Code) == "string" then value.Code else nil)
				daysLeft:set(if type(value.DaysLeft) == "number" then value.DaysLeft else 0)
			end
		end

		local function join()
			local clean = string.gsub(Fusion.peek(typed), "%s", "")
			if #clean == CODE_LENGTH then
				PrivateServerService.Join:Fire(clean)
			end
		end

		local function row(height: number): UDim2
			return UDim2.new(ROW_WIDTH, UDim.new(0, height))
		end

		local yourCode = Kit.TextInput(scope, {
			Name = "YourCode",
			Text = scope:Computed(function(use): string
				return use(code) or "None"
			end),
			TextSize = Kit.TextSize.Heading,
			Size = row(BOX_HEIGHT),
			LayoutOrder = 2,
		})
		-- Read-only display that can still be selected and copied.
		yourCode.TextEditable = false

		local connection = PrivateServerService.Status:Connect(apply)
		table.insert(scope, function()
			connection:Disconnect()
		end)
		PrivateServerService:GetStatus():andThen(apply):catch(warn)

		local screen = Kit.Screen(scope, {
			Name = "Private",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				Kit.Button(scope, {
					Name = "MainMenuButton",
					Text = "Main Menu",
					Variant = "Blue",
					TextSize = Kit.TextSize.Heading,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, MENU_BUTTON_Y),
					Size = MENU_BUTTON_SIZE,
					OnClick = function()
						context.Close()
					end,
				}),

				Kit.Panel(scope, {
					Name = "Main",
					Image = "",
					Color = OUTER_COLOR,
					Transparency = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
					Padding = INSET,
					Children = {
						scope:New("UICorner")({ CornerRadius = CORNER }),
						-- Named "Window": NavigationController gives such a screen the gamepad selection.
						Kit.Panel(scope, {
							Name = "Window",
							Image = "",
							Color = INNER_COLOR,
							Transparency = 0,
							Size = UDim2.fromScale(1, 1),
							Children = {
								scope:New("UICorner")({ CornerRadius = CORNER }),
								Kit.Stack(scope, {
									Name = "Rows",
									Gap = Kit.Space.M,
									Padding = Kit.Space.L,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Size = UDim2.fromScale(1, 1),
									Children = {
										Kit.Label(scope, {
											Name = "YourCodeCaption",
											Text = "Your Code",
											TextSize = Kit.TextSize.Small,
											Size = row(CAPTION_HEIGHT),
											LayoutOrder = 1,
										}),
										yourCode,
										Kit.Button(scope, {
											Name = "Generate",
											Text = "Generate",
											Variant = "Blue",
											Size = row(BUTTON_HEIGHT),
											LayoutOrder = 3,
											OnClick = function()
												PrivateServerService.Generate:Fire()
											end,
										}),
										Kit.Button(scope, {
											Name = "Buy",
											Text = "Buy 30 Days",
											Variant = "Blue",
											Size = row(BUTTON_HEIGHT),
											LayoutOrder = 4,
											OnClick = function()
												PrivateServerService.Buy:Fire()
											end,
										}),
										Kit.Label(scope, {
											Name = "DaysLeft",
											Text = scope:Computed(function(use): string
												return `{use(daysLeft)} Days Left`
											end),
											TextSize = Kit.TextSize.Heading,
											Size = row(LABEL_HEIGHT),
											LayoutOrder = 5,
										}),
										Kit.Divider(scope, { LayoutOrder = 6 }),
										Kit.TextInput(scope, {
											Name = "JoinCode",
											Placeholder = "Enter Code",
											TextSize = Kit.TextSize.Heading,
											Size = row(BOX_HEIGHT),
											LayoutOrder = 7,
											OnChanged = function(text: string)
												typed:set(text)
											end,
											OnSubmit = function(text: string)
												typed:set(text)
												join()
											end,
										}),
										-- Greyed out until the box holds a whole code; the server checks it.
										Kit.Button(scope, {
											Name = "Join",
											Text = "Join",
											Variant = "Blue",
											Size = row(BUTTON_HEIGHT),
											LayoutOrder = 8,
											Disabled = scope:Computed(function(use): boolean
												return #string.gsub(use(typed), "%s", "") ~= CODE_LENGTH
											end),
											OnClick = join,
										}),
									},
								}),
							} :: { any },
						}),
					} :: { any },
				}),
			},
		})

		-- The gamepad's B closes it like "Main Menu" does, whichever button holds the selection.
		Closers.register(scope, screen, context.Close)
		return screen
	end,
}
