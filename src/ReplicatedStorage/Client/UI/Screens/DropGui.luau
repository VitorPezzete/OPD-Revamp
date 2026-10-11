--!strict
--[[
	The drop prompt of plain items: holding a compass, a box or a drink shows its name
	with a button to drop it on the ground. Fruits have their own prompt (GiverGUI).

	The server drops whatever is held, so the button sends nothing but the request
	(ItemDropController, which also keeps the cooldown).

	Touch screens and gamepads only: a keyboard drops with Backspace (ItemDropController)
	and is shown nothing. On a gamepad the prompt carries the picture of the View / Select
	button, which puts the selection on "Drop" (NavigationController:SetPrompt); A then
	presses it, as in any window.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local HeldTool = require(ReplicatedStorage.Client.UI.Util.HeldTool)
local PadIcons = require(ReplicatedStorage.Client.UI.Util.PadIcons)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

-- The game's "drop" pictogram.
local DROP_ICON = "rbxassetid://89243894789752"
local BUTTON_HEIGHT = 40
local NAME_WIDTH = 280
-- The button NavigationController gives the selection with.
local SELECT_BUTTON = "ButtonSelect"
local SELECT_ICON_SIZE = 30

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local ItemDropController = Knit.GetController("ItemDropController")
		local InputController = Knit.GetController("InputController")
		local NavigationController = Knit.GetController("NavigationController")

		local held = HeldTool.observe(scope)
		-- The tool whose prompt was closed or used; equipping again brings it back.
		local dismissed: Fusion.Value<Tool?> = scope:Value(nil :: Tool?)
		local deviceKind = scope:Value(InputController:GetDeviceKind())
		-- A Signal connection is not something a scope can clean up by itself.
		local kindConnection = InputController.DeviceKindChanged:Connect(function(kind: string)
			deviceKind:set(kind)
		end)
		table.insert(scope, function()
			kindConnection:Disconnect()
		end)
		local onPad = scope:Computed(function(use): boolean
			return use(deviceKind) == "Gamepad"
		end)

		local droppable = scope:Computed(function(use): Tool?
			local tool = use(held)
			if use(deviceKind) == "KeyboardMouse" or not tool or tool == use(dismissed) then
				return nil
			end
			return if ItemDropController:CanDrop(tool) then tool else nil
		end)

		scope:Observer(held):onChange(function()
			if Fusion.peek(held) == nil then
				dismissed:set(nil)
			end
		end)

		local panel: Instance

		local function dismiss()
			dismissed:set(Fusion.peek(held))
			-- The selection must not stay on a button that is gone.
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(panel) then
				GuiService.SelectedObject = nil
			end
		end

		local function drop()
			if Fusion.peek(droppable) and ItemDropController:Drop() then
				dismiss()
			end
		end

		panel = UI.Panel(scope, {
			Name = "Prompt",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.3),
			AutomaticSize = Enum.AutomaticSize.XY,
			Color = Theme.Colors.Background,
			Transparency = Theme.Transparency.Hud,
			Padding = Theme.Space.M,
			Visible = scope:Computed(function(use): boolean
				return use(droppable) ~= nil
			end),
			Children = {
				UI.Stack(scope, {
					Name = "Row",
					Direction = "Horizontal",
					Gap = Theme.Space.M,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Children = {
						scope:New("ImageLabel")({
							Name = "SelectHint",
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(SELECT_ICON_SIZE, SELECT_ICON_SIZE),
							Image = scope:Computed(function(use): string
								return if use(onPad) then PadIcons.image(SELECT_BUTTON) else ""
							end),
							Visible = onPad,
							LayoutOrder = 0,
						}),
						UI.Stack(scope, {
							Name = "Item",
							Gap = 0,
							Size = UDim2.fromOffset(NAME_WIDTH, BUTTON_HEIGHT),
							VerticalAlignment = Enum.VerticalAlignment.Center,
							LayoutOrder = 1,
							Children = {
								UI.Label(scope, {
									Name = "Heading",
									Text = "HOLDING",
									Variant = "Tiny",
									Font = Theme.Fonts.Heading,
									Color = Theme.Colors.Accent,
									LayoutOrder = 1,
								}),
								UI.Label(scope, {
									Name = "ItemName",
									Text = scope:Computed(function(use): string
										local tool = use(droppable)
										return if tool then tool.Name else ""
									end),
									Variant = "BodyBold",
									Scaled = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, 24),
									LayoutOrder = 2,
								}),
							},
						}),
						UI.Button(scope, {
							Name = "Drop",
							Text = "Drop",
							Icon = DROP_ICON,
							Size = UDim2.fromOffset(130, BUTTON_HEIGHT),
							LayoutOrder = 2,
							OnClick = drop,
						}),
						UI.Button(scope, {
							Name = "Close",
							Text = "X",
							Variant = "Ghost",
							Size = UDim2.fromOffset(BUTTON_HEIGHT, BUTTON_HEIGHT),
							LayoutOrder = 3,
							OnClick = dismiss,
						}),
					},
				}),
			},
		})

		NavigationController:SetPrompt(panel)
		table.insert(scope, function()
			NavigationController:ClearPrompt(panel)
		end)

		return UI.Screen(scope, {
			Name = "DropGui",
			DisplayOrder = 2,
			Children = { panel },
		})
	end,
}
