--!strict
--[[
	Local side of fishing: the rod's click and everything that is only looks.

	Input: using a held rod sends Cast(aim) when no line is out and Reel() when one is.
	The server decides what either means.

	Visuals, for every character in view: the bobber with its line, drawn from the
	character's replicated "FishingBobber" status (a position). The bobber glows while
	"FishingBite" is set. Neither exists on the server; the legacy rods created the
	bobber, a BodyVelocity and a rope there for every cast.

	The rod itself comes with the held tool, like the model of every other weapon
	(Server.Modules.WeaponModels): the line starts at its "Line" attachment.
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)

local BOBBER_ATTRIBUTE = "FishingBobber"
local BITE_ATTRIBUTE = "FishingBite"
local BOBBER_TEMPLATE = "Bobber"
local ARM_NAME = "Right Arm"
local TIP_NAME = "Line"
local AIM_DISTANCE = 300
local CAST_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LOCAL_COOLDOWN = 0.3

type Line = { Bobber: BasePart, Beam: Beam, TipAttachment: Attachment?, Effect: ParticleEmitter? }
type View = { Line: Line? }

local FishingController = Knit.CreateController({
	Name = "FishingController",
})

local FishingService

local localPlayer = Players.LocalPlayer
local views: { [Model]: View } = {}
local templates: { [string]: Instance | false } = {}
local lastUse = 0

-- Visual templates live somewhere under Assets.Models; found once by name.
local function findTemplate(name: string): Instance?
	local cached = templates[name]
	if cached ~= nil then
		return cached or nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local found: Instance? = nil
	for _, descendant in if models then models:GetDescendants() else {} do
		if descendant.Name == name and (descendant:IsA("BasePart") or descendant:IsA("Model")) then
			found = descendant
			break
		end
	end
	if not found then
		warn(`[FishingController] No model named "{name}" under ReplicatedStorage.Assets.Models`)
	end
	templates[name] = found or false
	return found
end

local function makeVisual(instance: Instance)
	for _, part in { instance, table.unpack(instance:GetDescendants()) } do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		elseif part:IsA("Script") or part:IsA("Constraint") or part:IsA("BodyMover") then
			part:Destroy()
		end
	end
end

local function getView(character: Model): View
	local view = views[character]
	if not view then
		view = {}
		views[character] = view
	end
	return view
end

-- The tip of the rod in hand: the tool carries its model (Server.Modules.WeaponModels).
local function getRodTip(character: Model): Attachment?
	local tool = character:FindFirstChildOfClass("Tool")
	local tip = if tool and FishingConfig.Rods[tool.Name] then tool:FindFirstChild(TIP_NAME, true) else nil
	return if tip and tip:IsA("Attachment") then tip else nil
end

local function removeLine(view: View)
	local line = view.Line
	if line then
		view.Line = nil
		line.Bobber:Destroy()
		if line.TipAttachment then
			line.TipAttachment:Destroy()
		end
	end
end

local function drawLine(character: Model, target: Vector3)
	local view = getView(character)
	removeLine(view)

	local bobber: BasePart
	local template = findTemplate(BOBBER_TEMPLATE)
	if template and template:IsA("BasePart") then
		bobber = template:Clone()
		makeVisual(bobber)
	else
		bobber = Instance.new("Part")
		bobber.Shape = Enum.PartType.Ball
		bobber.Size = Vector3.new(0.6, 0.6, 0.6)
		bobber.Color = Color3.fromRGB(255, 60, 60)
		bobber.Material = Enum.Material.SmoothPlastic
		makeVisual(bobber)
	end
	bobber.Name = "FishingBobber"
	bobber.Anchored = true
	bobber.Transparency = 0

	-- The line starts at the rod's tip; without a rod model, at the hand.
	local tip = getRodTip(character)
	local ownTip: Attachment? = nil
	if not tip then
		local arm = character:FindFirstChild(ARM_NAME) or character.PrimaryPart
		if arm and arm:IsA("BasePart") then
			ownTip = Instance.new("Attachment")
			ownTip.Position = Vector3.new(0, -1, 0)
			ownTip.Parent = arm
			tip = ownTip
		end
	end

	local floatAttachment = Instance.new("Attachment")
	floatAttachment.Parent = bobber

	local beam = Instance.new("Beam")
	beam.Attachment0 = tip
	beam.Attachment1 = floatAttachment
	beam.Width0 = 0.05
	beam.Width1 = 0.05
	beam.FaceCamera = true
	beam.Segments = 12
	beam.CurveSize0 = -1
	beam.CurveSize1 = 1
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	beam.Parent = bobber

	local effect = bobber:FindFirstChild("Effect")
	local emitter = if effect and effect:IsA("ParticleEmitter") then effect else nil
	if emitter then
		emitter.Enabled = character:GetAttribute(BITE_ATTRIBUTE) == true
	end

	bobber.Position = if tip then tip.WorldPosition else target
	bobber.Parent = Workspace
	TweenService:Create(bobber, CAST_TWEEN, { Position = target }):Play()

	view.Line = { Bobber = bobber, Beam = beam, TipAttachment = ownTip, Effect = emitter }
end

local function watchCharacter(character: Model)
	local function updateLine()
		local target = character:GetAttribute(BOBBER_ATTRIBUTE)
		if typeof(target) == "Vector3" then
			drawLine(character, target)
		else
			removeLine(getView(character))
		end
	end

	local function updateBite()
		local line = getView(character).Line
		if line and line.Effect then
			line.Effect.Enabled = character:GetAttribute(BITE_ATTRIBUTE) == true
		end
	end

	character:GetAttributeChangedSignal(BOBBER_ATTRIBUTE):Connect(updateLine)
	character:GetAttributeChangedSignal(BITE_ATTRIBUTE):Connect(updateBite)

	character.Destroying:Once(function()
		local view = views[character]
		if view then
			views[character] = nil
			removeLine(view)
		end
	end)

	updateLine()
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

local function getAim(character: Model): Vector3
	local camera = Workspace.CurrentCamera
	local location = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(location.X, location.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

local function useRod(tool: Tool)
	local character = localPlayer.Character
	local now = os.clock()
	if not character or tool.Parent ~= character or now - lastUse < LOCAL_COOLDOWN then
		return
	end
	lastUse = now

	if character:GetAttribute(BOBBER_ATTRIBUTE) ~= nil then
		-- The gamepad variant of the minigame is for the ten-foot (console) interface, as before.
		FishingService.Reel:Fire(GuiService:IsTenFootInterface())
	else
		FishingService.Cast:Fire(getAim(character))
	end
end

local function watchOwnTools(character: Model)
	local bound: { [Tool]: boolean } = {}
	local function bind(child: Instance)
		if child:IsA("Tool") and FishingConfig.Rods[child.Name] and not bound[child] then
			bound[child] = true
			child.Activated:Connect(function()
				useRod(child)
			end)
		end
	end
	character.ChildAdded:Connect(bind)
	for _, child in character:GetChildren() do
		bind(child)
	end
end

function FishingController:KnitStart()
	FishingService = Knit.GetService("FishingService")

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	localPlayer.CharacterAdded:Connect(watchOwnTools)
	if localPlayer.Character then
		watchOwnTools(localPlayer.Character)
	end
end

return FishingController
