--!strict
--[[
	The editor of the "Custom" control layout, opened from the Settings tab ("Customize",
	shown while Settings.Control_Layout is "Custom").

	It works on ControlsController's draft: nothing reaches the server before Save, and
	every change shows at once on the real thing - the camera moves, the aim cross moves,
	the touch buttons move, grow and shrink where they really are. Closing the editor in
	any way but Save throws the draft away and everything goes back to what is saved.

	Pages:
	- Camera (gamepad and touch): the camera offset, one stepper per axis.
	- Aim (gamepad and touch): the aim offset, one stepper per axis. The cross is the one
	  AimReticle draws, on the real aim point.
	- Buttons (touch screens only): the buttons themselves are the editor. They are the
	  real ones of MobileContext and of the ability bar, put in editing mode by
	  UI.Util.TouchControls: touching one selects it, dragging it moves it. The page shows
	  the selected button with its size, its behaviour (cycled, each with a line saying
	  what it does) and a way back to the default button.
	Under the pages: Save, Cancel and Reset all (the whole draft back to the default
	layout; saved only by Save, like any other change).

	While it is open InputController is suspended (ControlsController:BeginEdit): touches,
	keys and gamepad buttons use nothing, so arranging the controls cannot attack or
	cast. The thumbstick and the camera keep working: the result is tried by moving around.

	The sheet is small and gets out of the way: "Move" sends it to the other side of the
	screen, "Hide" folds it down to its title bar, so every button stays reachable on a
	phone held sideways. Everything on it is a button the D-pad reaches, and B closes it
	(a UI.Window: see NavigationController). It closes by itself when the character goes
	away or the layout is no longer "Custom" (set to "Default" or "Auto").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

local peek = Fusion.peek

local CAMERA = "Camera"
local AIM = "Aim"
local BUTTONS = "Buttons"

-- Design pixels.
local MARGIN = 16
local WIDTH = 540
local HEIGHT = 440
-- The title bar of UI.Window: what is left of the sheet when it is folded.
local HEADER_HEIGHT = 52
local WINDOW_PADDING = Theme.Space.L
local TABS_HEIGHT = 36
local ROW_HEIGHT = 44
local ROW_GAP = 6
local LINE_HEIGHT = 24
local FOOTER_HEIGHT = 40
local ARROW_SIZE = UDim2.fromOffset(52, 40)
local VALUE_WIDTH = 110
local HEADER_BUTTON = UDim2.fromOffset(84, 34)
local FOOTER_BUTTON = UDim2.fromOffset(120, FOOTER_HEIGHT)

local CAMERA_HINT = "Moves the camera off your character, in studs."
local AIM_HINT = "Moves the aim cross on the screen."
local BUTTONS_HINT = "Drag a button to move it. Touch it to select it."
local NO_SELECTION = "No button selected"
local ENGINE_NOTE = "The jump button and the stick belong to Roblox and stay put."
local SAVING = "Saving..."
local SAVE_FAILED = "Not saved. Try again in a moment."
local RESET_DONE = "Everything is back to default. Save to keep it."

return {
	-- On a phone the engine's tool bar would be drawn over the editor (UIController).
	HidesHotbar = true,
	Mount = function(scope: Scope, _gui: any, context: any)
		local ControlsController = Knit.GetController("ControlsController")
		local AbilityController = Knit.GetController("AbilityController")
		local touch = UserInputService.TouchEnabled

		-- First in the scope, so last to be cleaned up: by then nothing below listens any more.
		ControlsController:BeginEdit()
		table.insert(scope, function()
			ControlsController:EndEdit()
		end)

		local alive = true
		table.insert(scope, function()
			alive = false
		end)
		local function own(connection: any)
			table.insert(scope, function()
				connection:Disconnect()
			end)
		end

		-- Bumped on every change of the draft: what the texts below are worked out from.
		local revision = scope:Value(0)
		local selected: Fusion.Value<string?> = scope:Value(ControlsController:GetSelected())
		local page = scope:Value(CAMERA)
		local folded = scope:Value(false)
		local onRight = scope:Value(false)
		local busy = scope:Value(false)
		local status = scope:Value("")

		local function close()
			-- Deferred: never from inside the callback that is still building or using the screen.
			task.defer(context.Close)
		end

		own(ControlsController.Changed:Connect(function()
			if not ControlsController:IsCustom() then
				-- No longer "Custom": there is nothing to edit.
				close()
				return
			end
			revision:set(peek(revision) + 1)
		end))
		own(ControlsController.SelectionChanged:Connect(function(id: string?)
			selected:set(id)
			-- A button touched on the screen brings its page up.
			if id and touch then
				page:set(BUTTONS)
			end
		end))
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			if not character then
				close()
			end
		end))
		if not ControlsController:IsCustom() then
			close()
		end

		---------------------------------------------------------------------------------
		-- Pieces.

		local function line(pageScope: Scope, order: number, text: UsedAs<string>, color: Color3?): Instance
			return UI.Label(pageScope, {
				Name = "Line",
				Text = text,
				Variant = "Small",
				Color = color,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
				LayoutOrder = order,
			})
		end

		-- "label ..... controls": the controls sit against the right edge.
		local function row(pageScope: Scope, order: number, label: UsedAs<string>, controls: Fusion.Child): Instance
			return pageScope:New("Frame")({
				Name = "Row",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				LayoutOrder = order,
				[Fusion.Children] = {
					UI.Label(pageScope, {
						Name = "Label",
						Text = label,
						Variant = "BodyBold",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(0.4, 0, 1, 0),
					}),
					UI.Stack(pageScope, {
						Name = "Controls",
						Direction = "Horizontal",
						Gap = Theme.Space.S,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.6, 0, 1, 0),
						Children = controls,
					}),
				},
			})
		end

		-- "<  value  >": one step down, the value, one step up.
		local function stepper(
			pageScope: Scope,
			text: UsedAs<string>,
			onStep: (steps: number) -> (),
			disabled: UsedAs<boolean>?
		): { Instance }
			local function arrow(glyph: string, steps: number, order: number): Instance
				return UI.Button(pageScope, {
					Name = if steps < 0 then "Less" else "More",
					Text = glyph,
					Variant = "Secondary",
					Size = ARROW_SIZE,
					LayoutOrder = order,
					Disabled = disabled,
					OnClick = function()
						onStep(steps)
					end,
				})
			end
			return {
				arrow("<", -1, 1),
				UI.Label(pageScope, {
					Name = "Value",
					Text = text,
					Variant = "BodyBold",
					Size = UDim2.new(0, VALUE_WIDTH, 1, 0),
					LayoutOrder = 2,
				}),
				arrow(">", 1, 3),
			}
		end

		-- A text worked out from the draft, again after each of its changes.
		local function fromDraft(pageScope: Scope, read: (controls: ControlsConfig.Controls, id: string?) -> string)
			return pageScope:Computed(function(use): string
				use(revision)
				return read(ControlsController:GetControls(), use(selected))
			end)
		end

		local function buttonName(id: string): string
			local definition = ControlsConfig.Buttons[id]
			local label = if definition then definition.Label else id
			if definition and definition.Kind == "Ability" then
				local ability = AbilityController:GetDefinition(id)
				if ability then
					return `{label}: {ability.Name}`
				end
			end
			return label
		end

		---------------------------------------------------------------------------------
		-- Pages.

		local function cameraPage(pageScope: Scope): { Instance }
			local function axis(order: number, label: string, name: string): Instance
				return row(
					pageScope,
					order,
					label,
					stepper(
						pageScope,
						fromDraft(pageScope, function(controls): string
							return string.format("%+.1f", (controls.CameraOffset :: any)[name])
						end),
						function(steps: number)
							ControlsController:StepCameraOffset(name, steps)
						end
					)
				)
			end
			return {
				line(pageScope, 1, CAMERA_HINT),
				axis(2, "Side", "X"),
				axis(3, "Height", "Y"),
				axis(4, "Distance", "Z"),
			}
		end

		local function aimPage(pageScope: Scope): { Instance }
			-- The screen's Y grows downwards; the stepper reads the other way: more is up.
			local function axis(order: number, label: string, name: string, sign: number): Instance
				return row(
					pageScope,
					order,
					label,
					stepper(
						pageScope,
						fromDraft(pageScope, function(controls): string
							local share = (controls.AimOffset :: any)[name] * sign
							return string.format("%+d%%", math.round(share * 100))
						end),
						function(steps: number)
							ControlsController:StepAimOffset(name, steps * sign)
						end
					)
				)
			end
			return {
				line(pageScope, 1, AIM_HINT),
				axis(2, "Sideways", "X", 1),
				axis(3, "Up / down", "Y", -1),
			}
		end

		local function buttonsPage(pageScope: Scope): { Instance }
			local none = pageScope:Computed(function(use): boolean
				return use(selected) == nil
			end)
			-- The behaviour in force for the selected button: its own, or its kind's default.
			local function behaviorOf(controls: ControlsConfig.Controls, id: string): string
				local entry = controls.Buttons[id]
				return if entry then entry.Behavior else ControlsConfig.DefaultBehavior(id)
			end
			local function withSelected(action: (id: string) -> ())
				local id = peek(selected)
				if id then
					action(id)
				end
			end

			return {
				line(pageScope, 1, BUTTONS_HINT),
				line(
					pageScope,
					2,
					pageScope:Computed(function(use): string
						local id = use(selected)
						return if id then buttonName(id) else NO_SELECTION
					end),
					Theme.Colors.Accent
				),
				row(
					pageScope,
					3,
					"Size",
					stepper(
						pageScope,
						fromDraft(pageScope, function(controls, id): string
							local entry = if id then controls.Buttons[id] else nil
							local scale = if entry then entry.Scale else ControlsConfig.Scale.Default
							return `{math.round(scale * 100)}%`
						end),
						function(steps: number)
							withSelected(function(id: string)
								ControlsController:StepButtonScale(id, steps)
							end)
						end,
						none
					)
				),
				row(
					pageScope,
					4,
					"Behavior",
					UI.Button(pageScope, {
						Name = "Behavior",
						Variant = "Secondary",
						TextSize = Theme.TextSize.Small,
						Size = UDim2.fromOffset(VALUE_WIDTH + 112, 40),
						Disabled = none,
						Text = fromDraft(pageScope, function(controls, id): string
							return if id then behaviorOf(controls, id) else "-"
						end),
						OnClick = function()
							withSelected(function(id: string)
								ControlsController:CycleButtonBehavior(id)
							end)
						end,
					})
				),
				line(
					pageScope,
					5,
					fromDraft(pageScope, function(controls, id): string
						return if id then ControlsConfig.BehaviorHint(id, behaviorOf(controls, id)) else ENGINE_NOTE
					end)
				),
				row(
					pageScope,
					6,
					"",
					UI.Button(pageScope, {
						Name = "ResetButton",
						Text = "Reset this button",
						Variant = "Secondary",
						TextSize = Theme.TextSize.Small,
						Size = UDim2.fromOffset(VALUE_WIDTH + 112, 40),
						Disabled = none,
						OnClick = function()
							withSelected(function(id: string)
								ControlsController:ResetButton(id)
							end)
						end,
					})
				),
			}
		end

		local content = scope:Computed(function(use, pageScope: Scope): { Instance }
			local current = use(page)
			if current == AIM then
				return aimPage(pageScope)
			elseif current == BUTTONS and touch then
				return buttonsPage(pageScope)
			end
			return cameraPage(pageScope)
		end)

		---------------------------------------------------------------------------------
		-- Save, cancel, reset.

		local function save()
			if peek(busy) then
				return
			end
			busy:set(true)
			status:set(SAVING)
			task.spawn(function()
				local saved = ControlsController:Save()
				if not alive then
					return
				end
				busy:set(false)
				if saved then
					context.Close()
				else
					status:set(SAVE_FAILED)
				end
			end)
		end

		local tabs: { { Key: string, Text: string } } = {
			{ Key = CAMERA, Text = "Camera" },
			{ Key = AIM, Text = "Aim" },
		}
		if touch then
			table.insert(tabs, { Key = BUTTONS, Text = "Buttons" })
		end

		local pageTop = TABS_HEIGHT + Theme.Space.S
		local pageBottom = FOOTER_HEIGHT + LINE_HEIGHT + Theme.Space.S

		local window = UI.Window(scope, {
			Title = "Controls",
			AnchorPoint = Vector2.new(0, 0),
			Position = scope:Computed(function(use): UDim2
				return if use(onRight)
					then UDim2.new(1, -(WIDTH + MARGIN), 0, MARGIN)
					else UDim2.fromOffset(MARGIN, MARGIN)
			end),
			Size = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(WIDTH, if use(folded) then HEADER_HEIGHT else HEIGHT)
			end),
			Padding = WINDOW_PADDING,
			OnClose = context.Close,
			HeaderChildren = {
				UI.Button(scope, {
					Name = "Move",
					Text = "Move",
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					Size = HEADER_BUTTON,
					LayoutOrder = 10,
					OnClick = function()
						onRight:set(not peek(onRight))
					end,
				}),
				UI.Button(scope, {
					Name = "Fold",
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					Size = HEADER_BUTTON,
					LayoutOrder = 20,
					Text = scope:Computed(function(use): string
						return if use(folded) then "Show" else "Hide"
					end),
					OnClick = function()
						folded:set(not peek(folded))
					end,
				}),
			},
			Children = scope:New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				-- Folded: only the title bar is left.
				Visible = scope:Computed(function(use): boolean
					return not use(folded)
				end),
				[Fusion.Children] = {
					UI.Tabs(scope, {
						Tabs = tabs,
						Selected = page,
						TabSize = UDim2.fromOffset(120, TABS_HEIGHT),
					}),
					UI.Stack(scope, {
						Name = "Page",
						Gap = ROW_GAP,
						Position = UDim2.fromOffset(0, pageTop),
						Size = UDim2.new(1, 0, 1, -(pageTop + pageBottom)),
						Children = content,
					}),
					UI.Label(scope, {
						Name = "Status",
						Text = status,
						Variant = "Small",
						Color = Theme.Colors.Warning,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 0, 1, -(FOOTER_HEIGHT + Theme.Space.XS)),
						Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
					}),
					UI.Stack(scope, {
						Name = "Footer",
						Direction = "Horizontal",
						Gap = Theme.Space.S,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
						Children = {
							UI.Button(scope, {
								Name = "ResetAll",
								Text = "Reset all",
								Variant = "Danger",
								TextSize = Theme.TextSize.Small,
								Size = FOOTER_BUTTON,
								LayoutOrder = 1,
								Disabled = busy,
								OnClick = function()
									ControlsController:ResetDraft()
									status:set(RESET_DONE)
								end,
							}),
							UI.Button(scope, {
								Name = "Cancel",
								Text = "Cancel",
								Variant = "Secondary",
								TextSize = Theme.TextSize.Small,
								Size = FOOTER_BUTTON,
								LayoutOrder = 2,
								OnClick = context.Close,
							}),
							UI.Button(scope, {
								Name = "Save",
								Text = "Save",
								Variant = "Success",
								TextSize = Theme.TextSize.Small,
								Size = FOOTER_BUTTON,
								LayoutOrder = 3,
								Disabled = busy,
								OnClick = save,
							}),
						},
					}),
				},
			}),
		})

		return UI.Screen(scope, {
			Name = "ControlsEditor",
			DisplayOrder = 20,
			Children = window,
		})
	end,
}
