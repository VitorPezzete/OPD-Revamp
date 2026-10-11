--!strict
--[[
	What a player without a cursor (gamepad, touch) aims with:

	- a small cross on the point attacks and abilities go through
	  (InputController:GetAimPoint). On touch always: the point is above the character's
	  head. A gamepad has the engine's own cursor, which is its aim point: no cross - until
	  the player moves the aim with the "Custom" control layout (ControlsController's aim
	  offset). The engine's cursor cannot be moved from here and stays where it was, so the
	  cross is then drawn on the moved point and is the aim; it also shows while the
	  controls editor is open, so that the offset can be seen being set;
	- with Aim Assist on, corner marks around the character the aim will land on
	  (InputController:GetAssistTarget, the same choice GetAimPosition makes); red while
	  the camera is locked onto it (CameraLockController);
	- while the camera is locked and its target is out of the picture (the player turned
	  away, or has it behind): an arrow on a ring around the centre of the screen, pointing
	  to where the target is relative to the camera, with the distance.

	Hidden with a mouse, on the spawn screen and while dead. The gui is placed in real
	pixels (ScreenScale is off for it): the marks follow a point of the 3D world.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local peek = Fusion.peek

-- Design pixels.
local CROSS_SIZE = 18
local CROSS_THICKNESS = 2
local MARK_SIZE = 64
local MARK_ARM = 14
local ARROW_SIZE = 34
-- Radius of the ring the arrow sits on, as a share of the smaller side of the screen.
local ARROW_RING = 0.36
-- The arrow shows once the target is this far (share of the screen) outside the picture's
-- centre, or behind the camera.
local ARROW_FROM = 0.46
local ARROW_GLYPH = "\u{25B2}"
-- Seconds between two searches for the target (its marks move every frame).
local SEARCH_INTERVAL = 0.1

-- One L-shaped corner of the target marks.
local function corner(
	scope: Scope,
	anchor: Vector2,
	size: Fusion.UsedAs<number>,
	thickness: Fusion.UsedAs<number>,
	color: Fusion.UsedAs<Color3>
): { Instance }
	local function bar(horizontal: boolean): Instance
		return scope:New("Frame")({
			AnchorPoint = anchor,
			Position = UDim2.fromScale(anchor.X, anchor.Y),
			Size = scope:Computed(function(use): UDim2
				return if horizontal
					then UDim2.fromOffset(use(size), use(thickness))
					else UDim2.fromOffset(use(thickness), use(size))
			end),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
	end
	return { bar(true), bar(false) }
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local InputController = Knit.GetController("InputController")
		local CameraLockController = Knit.GetController("CameraLockController")
		local ControlsController = Knit.GetController("ControlsController")
		local hud = Knit.GetController("UIController"):GetHudState()

		local deviceKind = scope:Value(InputController:GetDeviceKind())
		local kindConnection = InputController.DeviceKindChanged:Connect(function(kind: string)
			deviceKind:set(kind)
		end)
		table.insert(scope, function()
			kindConnection:Disconnect()
		end)

		local locked = scope:Value(CameraLockController:GetTarget() ~= nil)
		local lockConnection = CameraLockController.Changed:Connect(function(lockTarget: BasePart?)
			locked:set(lockTarget ~= nil)
		end)
		table.insert(scope, function()
			lockConnection:Disconnect()
		end)
		local markColor = scope:Computed(function(use): Color3
			return if use(locked) then Theme.Colors.Danger else Theme.Colors.Accent
		end)

		local hasCharacter = scope:Value(LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			hasCharacter:set(character ~= nil)
		end))

		-- Gamepad: whether the aim is somewhere else than under the engine's cursor (or
		-- is being set in the controls editor), so that it needs a cross of its own.
		local function isAimMoved(): boolean
			return ControlsController:IsEditing() or ControlsController:GetAimOffset() ~= Vector2.zero
		end
		local aimMoved = scope:Value(isAimMoved())
		local movedConnection = ControlsController.Changed:Connect(function()
			aimMoved:set(isAimMoved())
		end)
		table.insert(scope, function()
			movedConnection:Disconnect()
		end)

		local active = scope:Computed(function(use): boolean
			return use(deviceKind) ~= "KeyboardMouse" and use(hasCharacter) and use(hud.Spawned)
		end)
		local crossShown = scope:Computed(function(use): boolean
			return use(active) and (use(deviceKind) == "Touch" or use(aimMoved))
		end)

		local function pixels(design: number): Fusion.Computed<number>
			return scope:Computed(function(use): number
				return math.max(1, math.floor(design * use(ScreenScale.Factor) + 0.5))
			end)
		end
		local crossSize = pixels(CROSS_SIZE)
		local crossThickness = pixels(CROSS_THICKNESS)
		local markSize = pixels(MARK_SIZE)
		local markArm = pixels(MARK_ARM)
		local arrowSize = pixels(ARROW_SIZE)

		-- The target's screen position, nil when there is none.
		local markPosition: Fusion.Value<Vector2?> = scope:Value(nil :: Vector2?)
		local crossPosition: Fusion.Value<Vector2?> = scope:Value(nil :: Vector2?)
		-- The arrow towards a locked target out of the picture: where it sits, its
		-- rotation (degrees) and the distance shown; nil when there is nothing to point at.
		local arrow: Fusion.Value<{ Position: Vector2, Rotation: number, Studs: number }?> = scope:Value(nil :: any)
		local target: BasePart? = nil
		local untilSearch = 0
		local connection: RBXScriptConnection? = nil

		local function stop()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			target = nil
			markPosition:set(nil)
			crossPosition:set(nil)
			arrow:set(nil)
		end

		local function pointAt(camera: Camera, lockTarget: BasePart?)
			if not lockTarget or not lockTarget.Parent then
				arrow:set(nil)
				return
			end
			local size = camera.ViewportSize
			local centre = size / 2
			-- In the camera's own space: X right, Y up, -Z forward.
			local relative = camera.CFrame:PointToObjectSpace(lockTarget.Position)
			local point = camera:WorldToViewportPoint(lockTarget.Position)
			local away = Vector2.new((point.X - centre.X) / size.X, (point.Y - centre.Y) / size.Y)
			if relative.Z < 0 and math.abs(away.X) < ARROW_FROM and math.abs(away.Y) < ARROW_FROM then
				arrow:set(nil)
				return
			end
			local direction = Vector2.new(relative.X, -relative.Y)
			if direction.Magnitude < 1e-3 then
				-- Straight behind: point down, "turn around".
				direction = Vector2.new(0, 1)
			end
			direction = direction.Unit
			arrow:set({
				Position = centre + direction * (math.min(size.X, size.Y) * ARROW_RING),
				Rotation = math.deg(math.atan2(direction.X, -direction.Y)),
				Studs = (lockTarget.Position - camera.CFrame.Position).Magnitude,
			})
		end
		local function step(delta: number)
			untilSearch -= delta
			if untilSearch <= 0 then
				untilSearch = SEARCH_INTERVAL
				target = InputController:GetAssistTarget()
			end
			local camera = Workspace.CurrentCamera
			local current = target
			if camera then
				crossPosition:set(InputController:GetAimPoint())
				pointAt(camera, CameraLockController:GetTarget())
			end
			if not camera or not current or not current.Parent then
				markPosition:set(nil)
				return
			end
			local point, onScreen = camera:WorldToViewportPoint(current.Position)
			markPosition:set(if onScreen then Vector2.new(point.X, point.Y) else nil)
		end
		-- The search only runs while there is something to aim for.
		scope:Observer(active):onBind(function()
			if peek(active) then
				if not connection then
					untilSearch = 0
					connection = RunService.RenderStepped:Connect(step)
				end
			else
				stop()
			end
		end)
		table.insert(scope, stop)

		local crossBar = function(horizontal: boolean): Instance
			return scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = scope:Computed(function(use): UDim2
					return if horizontal
						then UDim2.fromOffset(use(crossSize), use(crossThickness))
						else UDim2.fromOffset(use(crossThickness), use(crossSize))
				end),
				BackgroundColor3 = Theme.Colors.White,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				[Fusion.Children] = scope:New("UIStroke")({
					Color = Theme.Colors.Black,
					Thickness = 1,
					Transparency = 0.3,
				}),
			})
		end

		local marks: { Instance } = {}
		for _, anchor in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			for _, piece in corner(scope, anchor, markArm, crossThickness, markColor) do
				table.insert(marks, piece)
			end
		end

		local gui = UI.Screen(scope, {
			Name = "AimReticle",
			DisplayOrder = 3,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Cross",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = scope:Computed(function(use): UDim2
						local point = use(crossPosition)
						return if point then UDim2.fromOffset(point.X, point.Y) else UDim2.fromScale(0.5, 0.5)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(use(crossSize), use(crossSize))
					end),
					BackgroundTransparency = 1,
					Visible = crossShown,
					[Fusion.Children] = { crossBar(true), crossBar(false) },
				}),
				scope:New("Frame")({
					Name = "TargetArrow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = scope:Computed(function(use): UDim2
						local pointer = use(arrow)
						return if pointer
							then UDim2.fromOffset(pointer.Position.X, pointer.Position.Y)
							else UDim2.fromScale(0.5, 0.5)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(use(arrowSize), use(arrowSize))
					end),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(active) and use(arrow) ~= nil
					end),
					[Fusion.Children] = {
						scope:New("TextLabel")({
							Name = "Arrow",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = ARROW_GLYPH,
							TextScaled = true,
							Font = Enum.Font.SourceSansBold,
							TextColor3 = Theme.Colors.Danger,
							TextStrokeColor3 = Theme.Colors.Black,
							TextStrokeTransparency = 0.2,
							Rotation = scope:Computed(function(use): number
								local pointer = use(arrow)
								return if pointer then pointer.Rotation else 0
							end),
						}),
						scope:New("TextLabel")({
							Name = "Distance",
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.fromScale(0.5, 1),
							Size = UDim2.fromScale(2.4, 0.5),
							BackgroundTransparency = 1,
							Text = scope:Computed(function(use): string
								local pointer = use(arrow)
								return if pointer then `{math.floor(pointer.Studs + 0.5)}m` else ""
							end),
							TextScaled = true,
							Font = Enum.Font.Arimo,
							TextColor3 = Theme.Colors.White,
							TextStrokeColor3 = Theme.Colors.Black,
							TextStrokeTransparency = 0.2,
						}),
					},
				}),
				scope:New("Frame")({
					Name = "Target",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = scope:Computed(function(use): UDim2
						local point = use(markPosition)
						return if point then UDim2.fromOffset(point.X, point.Y) else UDim2.fromScale(0.5, 0.5)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(use(markSize), use(markSize))
					end),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(active) and use(markPosition) ~= nil
					end),
					[Fusion.Children] = marks,
				}),
			},
		})
		-- Placed in real pixels: the scaler must leave this gui alone.
		gui:SetAttribute("ScreenScale", false)
		return gui
	end,
}
