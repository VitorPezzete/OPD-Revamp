--!strict
--[[
	The drop prompt of plain items: holding a compass, a box or a drink shows its name
	with a button to drop it on the ground. Fruits have their own prompt (GiverGUI).

	The old look: a light blue rounded plate under the top of the screen with the item's
	name on a blue bar, and a round button on each top corner, half outside the plate: the
	drop button on the left, the X on the right.

	The server drops whatever is held, so the button sends nothing but the request
	(ItemDropController, which also keeps the cooldown).

	Touch screens and gamepads only, as in the rework's: a keyboard drops with Backspace
	(ItemDropController). On a gamepad the View / Select button puts the selection on the
	drop button (NavigationController:SetPrompt).
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local HeldTool = require(ReplicatedStorage.Client.UI.Util.HeldTool)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

-- The old plate on a 1920x1080 screen (four times as wide as tall).
local SIZE = Vector2.new(408, 102)
local PLATE = "rbxassetid://90291183096901"
local PLATE_COLOR = Color3.fromRGB(131, 181, 255)
local PLATE_SLICE = Rect.new(50, 50, 50, 50)
local DROP_ICON = "rbxassetid://89243894789752"
local NAME_SIZE = Vector2.new(328, 56)
-- The corner buttons: a fifth of the plate's width.
local CORNER_SIZE = 80

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

		-- A round button centred on a top corner of the plate.
		local function corner(name: string, side: number, text: string?, icon: string?, onClick: () -> ()): Instance
			return Kit.Button(scope, {
				Name = name,
				Text = text or "",
				Variant = "Ghost",
				TextSize = Kit.TextSize.Title,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(side, 0),
				Size = UDim2.fromOffset(CORNER_SIZE, CORNER_SIZE),
				OnClick = onClick,
				Children = {
					Kit.Image(scope, {
						Name = "Disc",
						Image = PLATE,
						Color = PLATE_COLOR,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 0,
					}),
					if icon
						then Kit.Image(scope, {
							Name = "Icon",
							Image = icon,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.5, 0.5),
							ZIndex = 2,
						})
						else nil,
				} :: { any },
			})
		end

		panel = scope:New("ImageLabel")({
			Name = "Prompt",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			BackgroundTransparency = 1,
			Image = PLATE,
			ImageColor3 = PLATE_COLOR,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = PLATE_SLICE,
			Visible = scope:Computed(function(use): boolean
				return use(droppable) ~= nil
			end),
			[Fusion.Children] = {
				-- The old name bar wore the engine's blue button skin; it is not a button.
				Kit.Panel(scope, {
					Name = "Item",
					Image = "",
					Color = Kit.Colors.Blue,
					Transparency = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(NAME_SIZE.X, NAME_SIZE.Y),
					Children = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, Kit.Space.S) }),
						Kit.Label(scope, {
							Name = "ItemName",
							Text = scope:Computed(function(use): string
								local tool = use(droppable)
								return if tool then tool.Name else ""
							end),
							TextSize = Kit.TextSize.Button,
							Fit = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(1, -2 * Kit.Space.M, 1, -Kit.Space.S),
						}),
					},
				}),
				corner("Drop", 0, nil, DROP_ICON, drop),
				corner("Close", 1, "X", nil, dismiss),
			},
		})

		NavigationController:SetPrompt(panel)
		table.insert(scope, function()
			NavigationController:ClearPrompt(panel)
		end)

		return Kit.Screen(scope, {
			Name = "DropGui",
			Children = { panel },
		})
	end,
}
