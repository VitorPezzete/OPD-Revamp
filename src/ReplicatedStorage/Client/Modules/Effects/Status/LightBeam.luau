--!strict
--[[
	Light fruit - Light Beam while the key is held: the laser itself, redrawn every frame.
	Status value: "<fruit slot>;<ability slot>;<range>;<spark diameter>;<fruit colors>".

	A 0.5 stud neon beam from the tip of the right arm, which points along it (the
	legacy client detached the arm from the shoulder; here the shoulder joint is turned
	locally and put back afterwards), and a neon spark of the damage diameter at its end.
	Yellow, the first fruit color, or dark with armament haki.

	Owner: the beam follows its own aim at once - a ray from the arm tip towards the aim
	point, as long as the range, stopping at the first thing it touches - and the aim
	point is sent to the server ten times a second as phase 3 inputs. The server resolves
	the damage from those; it ends the beam by itself if they stop coming.

	Everyone else: the beam ends where the server resolved its last damage tick (the
	"LightBeamEnd" attribute, ten times a second), eased between two updates.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- With a second held ability streaming too this stays inside AbilityConfig.InputBudget.
local SEND_INTERVAL = 0.1
-- Frame times never add up exactly: a frame this close to the interval sends.
local FRAME_SLACK = 0.005
local END_ATTRIBUTE = "LightBeamEnd"
local HAKI_ATTRIBUTE = "Haki"

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 0)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local BEAM_THICKNESS = 0.5
local MIN_SPARK = 0.5
-- How fast the beam of another player closes on a new end point (per second).
local EASE_RATE = 25
-- Where the beam starts without a standard right arm, from the root.
local FALLBACK_ORIGIN = Vector3.new(1.5, 0.5, -1)

local function neon(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local range = tonumber(fields[3]) or 0
	local sparkSize = math.max(tonumber(fields[4]) or 0, MIN_SPARK)
	local color = EffectAssets.Colors(fields[5], DEFAULT_COLOR, DEFAULT_COLOR)

	local beam = neon()
	local spark = neon()
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.new(sparkSize, sparkSize, sparkSize)

	local foundTorso = character:FindFirstChild("Torso")
	local foundArm = character:FindFirstChild("Right Arm")
	local joint = foundTorso and foundTorso:FindFirstChild("Right Shoulder")
	local torso: BasePart? = if foundTorso and foundTorso:IsA("BasePart") then foundTorso else nil
	local arm: BasePart? = if foundArm and foundArm:IsA("BasePart") then foundArm else nil
	local shoulder: Motor6D? = if joint and joint:IsA("Motor6D") then joint else nil
	local restingC0 = if shoulder then shoulder.C0 else CFrame.identity

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local abilityService = if isLocal and fruitSlot and abilitySlot then Knit.GetService("AbilityService") else nil
	local inputController = if isLocal then Knit.GetController("InputController") else nil
	local sinceSend = SEND_INTERVAL
	local shownEnd: Vector3? = nil

	-- Turns the arm towards `target` and returns its tip, where the beam starts.
	local function point(target: Vector3): Vector3?
		if not torso or not arm or not shoulder then
			local root = character:FindFirstChild("HumanoidRootPart")
			return if root and root:IsA("BasePart") then root.CFrame:PointToWorldSpace(FALLBACK_ORIGIN) else nil
		end
		local socket = torso.CFrame:PointToWorldSpace(Vector3.new(torso.Size.X / 2, torso.Size.Y / 4, 0))
		local offset = target - socket
		if offset.Magnitude < 0.05 then
			return socket
		end
		local direction = offset.Unit
		local length = arm.Size.Y
		local wanted = CFrame.lookAt(socket + direction * (length / 2), socket + direction * length)
			* CFrame.Angles(math.rad(90), 0, 0)
		-- arm = torso * C0 * Transform * C1^-1, solved for C0.
		shoulder.C0 = torso.CFrame:ToObjectSpace(wanted) * shoulder.C1 * shoulder.Transform:Inverse()
		return socket + direction * length
	end

	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local target: Vector3? = nil
		if inputController then
			local aim: Vector3 = inputController:GetAimPosition()
			target = aim
			sinceSend += deltaTime
			if abilityService and sinceSend >= SEND_INTERVAL - FRAME_SLACK then
				sinceSend = 0
				abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
			end
		else
			local resolved = character:GetAttribute(END_ATTRIBUTE)
			if typeof(resolved) == "Vector3" then
				local shown = shownEnd or resolved
				shown = shown:Lerp(resolved, 1 - math.exp(-EASE_RATE * deltaTime))
				shownEnd = shown
				target = shown
			end
		end

		local origin = if target then point(target) else nil
		if not target or not origin then
			beam.Parent = nil
			spark.Parent = nil
			return
		end

		local finish = target
		if inputController then
			local offset = target - origin
			if offset.Magnitude > 0.05 and range > 0 then
				local reach = offset.Unit * range
				local result = Workspace:Raycast(origin, reach, params)
				finish = if result then result.Position else origin + reach
			end
		end

		local shade = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_COLOR else color
		beam.Color = shade
		spark.Color = shade

		local length = (finish - origin).Magnitude
		if length > 0.05 then
			beam.Size = Vector3.new(BEAM_THICKNESS, BEAM_THICKNESS, length)
			beam.CFrame = CFrame.lookAt(origin, finish) * CFrame.new(0, 0, -length / 2)
			beam.Parent = World.Effects()
		else
			beam.Parent = nil
		end
		spark.CFrame = CFrame.new(finish)
		spark.Parent = World.Effects()
	end)

	return function()
		connection:Disconnect()
		beam:Destroy()
		spark:Destroy()
		if shoulder then
			shoulder.C0 = restingC0
		end
	end
end
