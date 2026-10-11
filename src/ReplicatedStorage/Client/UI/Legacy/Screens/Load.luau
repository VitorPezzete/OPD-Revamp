--!strict
--[[
	Spawn screen (legacy Load): up whenever the local player has no character, that is
	from the moment the data is loaded until Spawn is pressed, and again after every death
	(the server removes the body and nothing respawns by itself). The camera hangs above
	and behind the selected spawn point; "<" / ">" walk through them, Spawn asks the
	server for a character there.

	The look is the old game's last spawn screen (the "Spawn" frame kept in the place under
	ServerStorage._Authoring.LegacyUI): the logo above the middle of the screen and, under
	it, a column of small blue buttons of one size wearing the engine's round button skin:
	"<" Spawn ">", Tutorial, Private Server, AFK World; "Changelogs" alone at the bottom of
	the screen. That frame placed everything in screen pixels from the middle of the
	screen; here the same numbers are design pixels of one panel (logo and buttons), so the
	screen scaler sizes them together on every screen. The frame has no changelog sheet
	(its bottom button was an unfinished copy of "Tutorial"): the blue sheet of the
	earlier screen is kept for it, on the right, read at one text size in a scrolling list.

	The spawn points are data (WorldConfig.Spawns): the legacy Workspace.Spawns and
	Workspace.CameraParts are gone. While the screen is up the camera is Scriptable; it is
	handed back (Custom, on the new Humanoid) as soon as a character exists.

	Legacy holes closed here: the client used to pick its spawn by editing its own
	SpawnNumber value and sending the number with the spawn request. Now it sends "previous"
	/ "next" (SpawnSelectService) and a bare spawn request (CharacterService.RequestSpawn);
	the destination is always the server's saved number.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local VersionConfig = require(ReplicatedStorage.Shared.Configs.VersionConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)

type Scope = Fusion.Scope<typeof(Fusion)>

-- "AFK Place" of the same experience.
local AFK_PLACE_ID = PlaceConfig.Places.AFK
-- How long the new character's Humanoid may take to arrive before the camera is released anyway.
local HUMANOID_TIMEOUT = 5
-- An accepted spawn whose character has not shown up after this long is given up on.
local ARRIVAL_TIMEOUT = 5
-- Screens that take the spawn screen's place while they are open.
local COVERING_SCREENS = { "Tutorial", "Private" }
-- Over the HUD, under the screens that cover it, like the rework's.
local DISPLAY_ORDER = 20

-- The "Spawn" frame, in its own pixels: a logo of 758 x 426 whose top is 354 above the
-- middle of the screen, and buttons of 150 x 50 every 60 pixels from 70 below it.
local LOGO = "rbxassetid://70816647124390"
local LOGO_SIZE = Vector2.new(758, 426)
local MENU_TOP = -354
local BUTTONS_TOP = 424
local BUTTON_SIZE = Vector2.new(150, 50)
local BUTTON_STEP = 60
local ARROW_SIZE = Vector2.new(50, 50)
-- From the middle of the panel to the near edge of an arrow.
local ARROW_OFFSET = 75
local BUTTON_ROWS = 4
local MENU_SIZE = Vector2.new(LOGO_SIZE.X, BUTTONS_TOP + (BUTTON_ROWS - 1) * BUTTON_STEP + BUTTON_SIZE.Y)
local BOTTOM_MARGIN = 2
local BUTTON_TEXT_SIZE = 22
-- The changelog sheet, on the right of the screen.
local CHANGELOG_SIZE = Vector2.new(468, 818)
local CHANGELOG_POSITION = UDim2.fromScale(0.836, 0.525)
local CHANGELOG_COLOR = Color3.fromRGB(76, 168, 255)

local localPlayer = Players.LocalPlayer

-- Whatever path led into the world, the camera must be the player's again.
local function releaseCamera(character: Model)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
		local current = Workspace.CurrentCamera
		if humanoid and humanoid:IsA("Humanoid") and current and localPlayer.Character == character then
			current.CameraType = Enum.CameraType.Custom
			current.CameraSubject = humanoid
		end
	end)
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, context: any)
		local UIController = Knit.GetController("UIController")
		local CharacterService = Knit.GetService("CharacterService")
		local SpawnSelectService = Knit.GetService("SpawnSelectService")

		local spawnNumber = Bind.data(scope, "SpawnNumber", nil)
		-- True from the click on Spawn until the server answers or the character arrives.
		local requested = scope:Value(false)
		local hasCharacter = scope:Value(LocalCharacter.Exists())
		local covered = scope:Value(false)
		local showChangelog = scope:Value(false)

		local visible = scope:Computed(function(use): boolean
			return use(spawnNumber) ~= nil and not use(hasCharacter) and not use(requested) and not use(covered)
		end)

		local function refreshCovered()
			for _, name in COVERING_SCREENS do
				if context.IsOpen(name) then
					covered:set(true)
					return
				end
			end
			covered:set(false)
		end
		local screenConnection = UIController.ScreenChanged:Connect(refreshCovered)
		table.insert(scope, function()
			screenConnection:Disconnect()
		end)
		refreshCovered()

		--[[
			Pinned every frame while the screen is up (client only, one CFrame write):
			with no character nothing else drives the camera, and a covering screen
			(Tutorial) that borrowed it gives it back just by closing.
		]]
		local cameraConnection: RBXScriptConnection? = nil
		local function pinCamera()
			local camera = Workspace.CurrentCamera
			local number = Fusion.peek(spawnNumber)
			if not camera or type(number) ~= "number" then
				return
			end
			local position = WorldConfig.GetSpawnPosition(number)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(position + WorldConfig.SpawnCameraOffset, position)
		end
		local function setPinned(pinned: boolean)
			if pinned and not cameraConnection then
				cameraConnection = RunService.RenderStepped:Connect(pinCamera)
				pinCamera()
			elseif not pinned and cameraConnection then
				cameraConnection:Disconnect()
				cameraConnection = nil
			end
		end
		scope:Observer(visible):onChange(function()
			setPinned(Fusion.peek(visible))
		end)
		setPinned(Fusion.peek(visible))
		table.insert(scope, function()
			setPinned(false)
		end)

		--[[
			The interface can be swapped while the player is in the world: this screen is
			then mounted with a character that has been playing for a while, and the camera
			is whatever the game made of it. It is only taken back from the spawn view (a
			Scriptable camera left by this screen or its twin), never from a camera in use.
		]]
		local mounting = true
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			local first = mounting
			mounting = false
			hasCharacter:set(character ~= nil)
			if character then
				requested:set(false)
				setPinned(false)
				local camera = Workspace.CurrentCamera
				if not first or (camera and camera.CameraType == Enum.CameraType.Scriptable) then
					releaseCamera(character)
				end
			end
		end))

		-- Nothing below may touch the state of a screen that was cleaned up meanwhile.
		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)

		local function spawn()
			if Fusion.peek(requested) then
				return
			end
			requested:set(true)
			CharacterService:RequestSpawn()
				:andThen(function(accepted: boolean)
					if not mounted then
						return
					end
					-- Refused (already spawning, rate limit): the screen comes back.
					if not accepted then
						requested:set(false)
						return
					end
					-- Accepted: the screen stays down until the character replicates
					-- here, which also clears the flag; this only covers it never coming.
					task.delay(ARRIVAL_TIMEOUT, function()
						if mounted and not LocalCharacter.Exists() then
							requested:set(false)
						end
					end)
				end)
				:catch(function()
					if mounted then
						requested:set(false)
					end
				end)
		end

		-- The engine's own round blue button, as the old screen: the Kit has no such skin.
		local function button(props: {
			Name: string,
			Text: string,
			Size: Vector2,
			Position: UDim2,
			AnchorPoint: Vector2?,
			Bold: boolean?,
			Selected: Fusion.UsedAs<boolean>?,
			OnClick: () -> (),
		}): Instance
			return scope:New("TextButton")({
				Name = props.Name,
				Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
				AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
				Position = props.Position,
				Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
				FontFace = if props.Bold then Kit.Fonts.Bold else Kit.Fonts.Regular,
				Text = props.Text,
				TextScaled = true,
				TextWrapped = true,
				TextColor3 = scope:Computed(function(use): Color3
					return if props.Selected ~= nil and use(props.Selected) then Kit.Colors.Selected else Kit.Colors.Text
				end),
				TextStrokeColor3 = Kit.Colors.Outline,
				TextStrokeTransparency = Kit.OutlineTransparency,
				[Fusion.OnEvent("Activated")] = props.OnClick,
				[Fusion.Children] = {
					scope:New("UITextSizeConstraint")({ MinTextSize = 8, MaxTextSize = BUTTON_TEXT_SIZE }),
				},
			})
		end

		-- A button of the column, by its row.
		local function rowPosition(row: number): UDim2
			return UDim2.new(0.5, 0, 0, BUTTONS_TOP + (row - 1) * BUTTON_STEP)
		end

		-- The config's text may use rich text, as in the rework's panel.
		local changelogText = Kit.Label(scope, {
			Name = "Changelogs",
			Text = VersionConfig.Changelog or "",
			TextSize = Kit.TextSize.Small,
			Bold = false,
			RichText = true,
			Wrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.fromScale(1, 0),
		})
		-- As wide as the sheet, as tall as the text: the Kit's label has no such mode.
		changelogText.AutomaticSize = Enum.AutomaticSize.Y

		local gui = Kit.Screen(scope, {
			Name = "Load",
			DisplayOrder = DISPLAY_ORDER,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Frame",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Visible = visible,
					[Fusion.Children] = {
						scope:New("Frame")({
							Name = "Menu",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0.5, MENU_TOP),
							Size = UDim2.fromOffset(MENU_SIZE.X, MENU_SIZE.Y),
							[Fusion.Children] = {
								Kit.Image(scope, {
									Name = "Icon",
									Image = LOGO,
									ScaleType = Enum.ScaleType.Stretch,
									Size = UDim2.fromOffset(LOGO_SIZE.X, LOGO_SIZE.Y),
								}),
								-- The new number comes back through the replicated data and
								-- moves the camera.
								button({
									Name = "Previous",
									Text = "<",
									Bold = true,
									Size = ARROW_SIZE,
									AnchorPoint = Vector2.new(1, 0),
									Position = rowPosition(1) - UDim2.fromOffset(ARROW_OFFSET, 0),
									OnClick = function()
										SpawnSelectService:Cycle(-1):catch(warn)
									end,
								}),
								button({
									Name = "Load",
									Text = "Spawn",
									Size = BUTTON_SIZE,
									Position = rowPosition(1),
									OnClick = spawn,
								}),
								button({
									Name = "Next",
									Text = ">",
									Bold = true,
									Size = ARROW_SIZE,
									AnchorPoint = Vector2.new(0, 0),
									Position = rowPosition(1) + UDim2.fromOffset(ARROW_OFFSET, 0),
									OnClick = function()
										SpawnSelectService:Cycle(1):catch(warn)
									end,
								}),
								button({
									Name = "Tutorial",
									Text = "Tutorial",
									Size = BUTTON_SIZE,
									Position = rowPosition(2),
									OnClick = function()
										context.Open("Tutorial")
									end,
								}),
								button({
									Name = "Private",
									Text = "Private Server",
									Size = BUTTON_SIZE,
									Position = rowPosition(3),
									OnClick = function()
										context.Open("Private")
									end,
								}),
								button({
									Name = "AFK",
									Text = "AFK World",
									Size = BUTTON_SIZE,
									Position = rowPosition(4),
									OnClick = function()
										local ok, problem =
											pcall(TeleportService.Teleport, TeleportService, AFK_PLACE_ID, localPlayer)
										if not ok then
											warn(`[Load] teleport to the AFK place failed: {problem}`)
										end
									end,
								}),
							},
						}),
						button({
							Name = "Changelogs",
							Text = "Changelogs",
							Size = BUTTON_SIZE,
							Selected = showChangelog,
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
							OnClick = function()
								showChangelog:set(not Fusion.peek(showChangelog))
							end,
						}),
						Kit.Panel(scope, {
							Name = "ChangelogSheet",
							Image = "",
							Color = CHANGELOG_COLOR,
							Transparency = 0.1,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = CHANGELOG_POSITION,
							Size = UDim2.fromOffset(CHANGELOG_SIZE.X, CHANGELOG_SIZE.Y),
							Visible = showChangelog,
							Children = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0, Kit.Space.S) }),
								Kit.Scroll(scope, {
									Name = "ScrollingFrame",
									Background = false,
									Padding = Kit.Space.M,
									Children = { changelogText },
								}),
							},
						}),
					},
				}),
			},
		})
		-- Inside the notch of a phone, as the old gui.
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		return gui
	end,
}
