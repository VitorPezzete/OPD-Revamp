--!strict
--[[
	Private server panel, opened from the spawn screen.

	Shows the player's code and days left, and sends three intents: generate a new code,
	buy 30 days, join the server behind a typed code. The server decides everything; the
	code box only carries what the player typed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type Status = { Code: string?, DaysLeft: number }

local CODE_LENGTH = 6
local ROW_HEIGHT = 48
local CODE_HEIGHT = 64
local CAPTION_HEIGHT = 20

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

		local connection = PrivateServerService.Status:Connect(apply)
		table.insert(scope, function()
			connection:Disconnect()
		end)
		PrivateServerService:GetStatus():andThen(apply):catch(warn)

		local function join()
			local clean = string.gsub(Fusion.peek(typed), "%s", "")
			if #clean == CODE_LENGTH then
				PrivateServerService.Join:Fire(clean)
			end
		end

		local function caption(text: string, order: number): Instance
			return UI.Label(scope, {
				Name = "Caption",
				Text = text,
				Variant = "Small",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
				LayoutOrder = order,
			})
		end

		return UI.Screen(scope, {
			Name = "Private",
			DisplayOrder = 30,
			Children = {
				UI.Window(scope, {
					Name = "Main",
					Title = "Private Server",
					Subtitle = scope:Computed(function(use): string
						return `{use(daysLeft)} Days Left`
					end),
					Size = UDim2.fromOffset(480, 500),
					OnClose = context.Close,
					Children = {
						UI.Stack(scope, {
							Name = "Rows",
							Size = UDim2.fromScale(1, 1),
							Gap = Theme.Space.S,
							Children = {
								caption("Your code", 1),
								-- Read-only, but it can still be selected and copied: the kit's
								-- TextInput is always editable, so this box is built here.
								scope:New("TextBox")({
									Name = "YourCode",
									Size = UDim2.new(1, 0, 0, CODE_HEIGHT),
									LayoutOrder = 2,
									BackgroundColor3 = Theme.Colors.Sunken,
									TextEditable = false,
									ClearTextOnFocus = false,
									FontFace = Theme.Fonts.Mono,
									Text = scope:Computed(function(use): string
										return use(code) or "None"
									end),
									TextColor3 = Theme.Colors.Accent,
									TextSize = Theme.TextSize.Title,
									[Fusion.Children] = {
										scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Small) }),
										scope:New("UIStroke")({
											ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											Color = Theme.Colors.Border,
											Thickness = 1,
										}),
									},
								}),
								scope:New("Frame")({
									Name = "Owner",
									Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
									BackgroundTransparency = 1,
									LayoutOrder = 3,
									[Fusion.Children] = {
										UI.Button(scope, {
											Name = "Generate",
											Text = "Generate",
											Variant = "Secondary",
											Size = UDim2.new(0.5, -Theme.Space.S / 2, 1, 0),
											OnClick = function()
												PrivateServerService.Generate:Fire()
											end,
										}),
										UI.Button(scope, {
											Name = "Buy",
											Text = "Buy 30 Days",
											AnchorPoint = Vector2.new(1, 0),
											Position = UDim2.fromScale(1, 0),
											Size = UDim2.new(0.5, -Theme.Space.S / 2, 1, 0),
											OnClick = function()
												PrivateServerService.Buy:Fire()
											end,
										}),
									},
								}),
								UI.Divider(scope, { LayoutOrder = 4 }),
								caption("Join a private server", 5),
								UI.TextInput(scope, {
									Name = "JoinCode",
									Text = typed,
									Placeholder = "Enter Code",
									TextXAlignment = Enum.TextXAlignment.Center,
									Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
									LayoutOrder = 6,
									OnSubmit = join,
								}),
								UI.Button(scope, {
									Name = "Join",
									Text = "Join",
									Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
									LayoutOrder = 7,
									-- Greyed out until the box holds a whole code; the server checks it.
									Disabled = scope:Computed(function(use): boolean
										return #string.gsub(use(typed), "%s", "") ~= CODE_LENGTH
									end),
									OnClick = join,
								}),
								UI.Button(scope, {
									Name = "MainMenuButton",
									Text = "Main Menu",
									Variant = "Ghost",
									Size = UDim2.new(1, 0, 0, 40),
									LayoutOrder = 8,
									OnClick = context.Close,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
