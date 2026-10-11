--!strict
--[[
	Spawn screen: up whenever the local player has no character, that is from the moment
	the data is loaded until Spawn is pressed, and again after every death (the server
	removes the body and nothing respawns by itself). The camera hangs above and behind
	the selected spawn point; the arrows walk through them, Spawn asks the server for a
	character there.

	The client never names a destination: it sends "previous" / "next"
	(SpawnSelectService) and a bare spawn request (CharacterService.RequestSpawn); the
	server spawns at its own saved number. While the screen is up the camera is
	Scriptable; it is handed back (Custom, on the new Humanoid) as soon as a character
	exists.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)
local UI = require(ReplicatedStorage.Client.UI.Components)
local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local VersionConfig = require(ReplicatedStorage.Shared.Configs.VersionConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)

type Scope = Theme.Scope

local LOGO = "rbxassetid://70816647124390"
-- "AFK Place" of the same experience.
local AFK_PLACE_ID = PlaceConfig.Places.AFK
-- How long the new character's Humanoid may take to arrive before the camera is released anyway.
local HUMANOID_TIMEOUT = 5
-- An accepted spawn whose character has not shown up after this long is given up on.
local ARRIVAL_TIMEOUT = 5
-- Screens that take the spawn screen's place while they are open.
local COVERING_SCREENS = { "Tutorial", "Private" }

local PANEL_WIDTH = 320
local BUTTON_HEIGHT = 40

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

		local visible = scope:Computed(function(use)
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

		table.insert(
			scope,
			LocalCharacter.Observe(function(character: Model?)
				hasCharacter:set(character ~= nil)
				if character then
					requested:set(false)
					setPinned(false)
					releaseCamera(character)
				end
			end)
		)

		local function spawn()
			if Fusion.peek(requested) then
				return
			end
			requested:set(true)
			CharacterService:RequestSpawn()
				:andThen(function(accepted: boolean)
					-- Refused (already spawning, rate limit): the screen comes back.
					if not accepted then
						requested:set(false)
						return
					end
					-- Accepted: the screen stays down until the character replicates
					-- here, which also clears the flag; this only covers it never coming.
					task.delay(ARRIVAL_TIMEOUT, function()
						if not LocalCharacter.Exists() then
							requested:set(false)
						end
					end)
				end)
				:catch(function()
					requested:set(false)
				end)
		end

		local function teleportToAfk()
			local ok, problem = pcall(TeleportService.Teleport, TeleportService, AFK_PLACE_ID, localPlayer)
			if not ok then
				warn(`[Load] teleport to the AFK place failed: {problem}`)
			end
		end

		local arrowSize = UDim2.fromOffset(BUTTON_HEIGHT, BUTTON_HEIGHT)
		local wide = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

		return UI.Screen(scope, {
			Name = "Load",
			DisplayOrder = 20,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Root",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Visible = visible,
					[Fusion.Children] = {
						UI.Image(scope, {
							Name = "Logo",
							Image = LOGO,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, 40),
							Size = UDim2.fromOffset(700, 470),
						}),

						UI.Panel(scope, {
							Name = "Menu",
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -56),
							Size = UDim2.fromOffset(PANEL_WIDTH, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							-- No box: the buttons stand on the world by themselves.
							Transparency = 1,
							Stroke = false,
							Children = {
								ScreenScale.boost(scope),
								UI.Stack(scope, {
									Name = "Rows",
									Size = UDim2.fromScale(1, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									Gap = Theme.Space.S,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									Children = {
										scope:New("Frame")({
											Name = "SpawnRow",
											Size = wide,
											BackgroundTransparency = 1,
											LayoutOrder = 2,
											[Fusion.Children] = {
												UI.Button(scope, {
													Name = "Previous",
													Text = "<",
													Variant = "Secondary",
													Size = arrowSize,
													OnClick = function()
														SpawnSelectService:Cycle(-1):catch(warn)
													end,
												}),
												UI.Button(scope, {
													Name = "Spawn",
													Text = "Spawn",
													Variant = "Secondary",
													AnchorPoint = Vector2.new(0.5, 0),
													Position = UDim2.fromScale(0.5, 0),
													Size = UDim2.new(1, -(BUTTON_HEIGHT + Theme.Space.S) * 2, 1, 0),
													OnClick = spawn,
												}),
												UI.Button(scope, {
													Name = "Next",
													Text = ">",
													Variant = "Secondary",
													AnchorPoint = Vector2.new(1, 0),
													Position = UDim2.fromScale(1, 0),
													Size = arrowSize,
													OnClick = function()
														SpawnSelectService:Cycle(1):catch(warn)
													end,
												}),
											},
										}),
										UI.Button(scope, {
											Name = "Tutorial",
											Text = "Tutorial",
											Variant = "Secondary",
											Size = wide,
											LayoutOrder = 4,
											OnClick = function()
												context.Open("Tutorial")
											end,
										}),
										UI.Button(scope, {
											Name = "Private",
											Text = "Private Server",
											Variant = "Secondary",
											Size = wide,
											LayoutOrder = 5,
											OnClick = function()
												context.Open("Private")
											end,
										}),
										UI.Button(scope, {
											Name = "Afk",
											Text = "AFK Place",
											Variant = "Secondary",
											Size = wide,
											LayoutOrder = 6,
											OnClick = teleportToAfk,
										}),
										UI.Button(scope, {
											Name = "Changelog",
											Text = "Changelog",
											Variant = "Secondary",
											TextSize = Theme.TextSize.Tiny,
											Size = UDim2.fromOffset(130, 28),
											LayoutOrder = 7,
											Selected = showChangelog,
											OnClick = function()
												showChangelog:set(not Fusion.peek(showChangelog))
											end,
										}),
									},
								}),
							},
						}),

						UI.Window(scope, {
							Name = "ChangelogWindow",
							Title = "Changelog",
							Subtitle = VersionConfig.Version,
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.new(1, -40, 1, -70),
							Size = UDim2.fromOffset(560, 640),
							Visible = showChangelog,
							OnClose = function()
								showChangelog:set(false)
							end,
							Children = {
								UI.Scroll(scope, {
									Padding = Theme.Space.M,
									Children = {
										UI.Label(scope, {
											Name = "Text",
											Text = VersionConfig.Changelog or "",
											Variant = "Small",
											Color = Theme.Colors.TextMuted,
											Wrapped = true,
											RichText = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Top,
											Size = UDim2.fromScale(1, 0),
											AutomaticSize = Enum.AutomaticSize.Y,
										}),
									},
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
