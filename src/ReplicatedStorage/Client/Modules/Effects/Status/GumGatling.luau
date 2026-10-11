--!strict
--[[
	Gum fruit - Gatling while the key is held.
	Status value: "<fruit slot>|<ability slot>".

	Every punch of the stream is its own GumPunch one-shot. Everyone: both real arms
	(and their haki shells) stay hidden for as long as the stream lasts, as in the legacy
	game. Owner: its client keeps the server's aim point on the mouse by sending it as the
	ability's secondary input a few times a second (the server fires the punches itself
	and only reads the position, after validating it).

	Owner, the pin. The legacy server put a BodyPosition "GatlingBP" in the root
	(MaxForce 1e6, P 100000, D 1000) at the spot the stream started from, on the ground
	or in the air, and a BodyGyro "GatlingBG" in the head (MaxTorque 1e8, P 100000)
	looking from the head at the target of each punch, pitch included. Both lived until
	the last punch of the stream was over (its arm back, 2 punch times + 0.2 s after it
	started). They are created here, the owner being the one who simulates its character;
	each punch (Effects.OneShot.GumPunch) turns the gyro and says how long they must last.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- Well under the per-player input budget (8 inputs per second).
local SEND_INTERVAL = 0.2
local AIM_DISTANCE = 500

local ARMS = { "Left Arm", "Right Arm" }

local HOLD_NAME = "GatlingBP"
local HOLD_FORCE = Vector3.new(1e6, 1e6, 1e6)
-- Shared with Effects.OneShot.GumPunch.
local GYRO_NAME = "GatlingBG"
local TAIL_ATTRIBUTE = "GumGatlingTail"
local GYRO_TORQUE = Vector3.new(1e8, 1e8, 1e8)
local PIN_POWER = 100000
local PIN_DAMPING = 1000
local HAKI_SHELL = "HakiShell"

-- Same counted hiding as Effects.OneShot.GumPunch (see there).
local HIDDEN_COUNT = "GumHiddenCount"
local HIDDEN_TRANSPARENCY = "GumHiddenTransparency"

local function hide(arm: BasePart)
	local count = arm:GetAttribute(HIDDEN_COUNT)
	if type(count) == "number" and count > 0 then
		arm:SetAttribute(HIDDEN_COUNT, count + 1)
		return
	end
	arm:SetAttribute(HIDDEN_TRANSPARENCY, arm.Transparency)
	arm:SetAttribute(HIDDEN_COUNT, 1)
	arm.Transparency = 1
	local shell = arm:FindFirstChild(HAKI_SHELL)
	if shell and shell:IsA("BasePart") then
		shell:SetAttribute(HIDDEN_TRANSPARENCY, shell.Transparency)
		shell.Transparency = 1
	end
end

local function show(arm: BasePart)
	local count = arm:GetAttribute(HIDDEN_COUNT)
	if type(count) ~= "number" then
		return
	end
	if count > 1 then
		arm:SetAttribute(HIDDEN_COUNT, count - 1)
		return
	end
	local transparency = arm:GetAttribute(HIDDEN_TRANSPARENCY)
	arm:SetAttribute(HIDDEN_COUNT, nil)
	arm:SetAttribute(HIDDEN_TRANSPARENCY, nil)
	arm.Transparency = if type(transparency) == "number" then transparency else 0
	-- A shell put on while the arm was hidden has nothing saved and is left alone.
	local shell = arm:FindFirstChild(HAKI_SHELL)
	local shellTransparency = shell and shell:GetAttribute(HIDDEN_TRANSPARENCY)
	if shell and shell:IsA("BasePart") and type(shellTransparency) == "number" then
		shell:SetAttribute(HIDDEN_TRANSPARENCY, nil)
		shell.Transparency = shellTransparency
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local hidden: { BasePart } = {}
	for _, name in ARMS do
		local arm = character:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			hide(arm)
			table.insert(hidden, arm)
		end
	end
	local function showArms()
		for _, arm in hidden do
			show(arm)
		end
	end

	local fields = EffectAssets.Unpack(value)
	local fruitSlot, abilitySlot = tonumber(fields[1]), tonumber(fields[2])
	if not isLocal or not fruitSlot or not abilitySlot then
		return showArms
	end

	local abilityService = Knit.GetService("AbilityService")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local function getAim(): Vector3?
		local camera = Workspace.CurrentCamera
		local root = character.PrimaryPart
		if not camera or not root or Players.LocalPlayer.Character ~= character then
			return nil
		end

		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, rayParams)
		local aim = if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE

		-- The server rejects aim points too far from the character: keep it in range.
		local offset = aim - root.Position
		local limit = AbilityConfig.MaxAimDistance - 10
		if offset.Magnitude > limit then
			aim = root.Position + offset.Unit * limit
		end
		return aim
	end

	-- The pin (see the header). A stream started while the movers of the previous one
	-- are still there takes them over, as the legacy server did.
	local movers: { Instance } = {}
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if root and root:IsA("BasePart") and head and head:IsA("BasePart") then
		local hold = root:FindFirstChild(HOLD_NAME)
		if not hold then
			local created = Instance.new("BodyPosition")
			created.Name = HOLD_NAME
			created.MaxForce = HOLD_FORCE
			created.P = PIN_POWER
			created.D = PIN_DAMPING
			created.Position = root.Position
			created.Parent = root
			hold = created
		end
		local turn = head:FindFirstChild(GYRO_NAME)
		if not turn then
			local created = Instance.new("BodyGyro")
			created.Name = GYRO_NAME
			created.MaxTorque = GYRO_TORQUE
			created.P = PIN_POWER
			local aim = getAim()
			if aim and (aim - head.Position).Magnitude > 1e-3 then
				created.CFrame = CFrame.lookAt(head.Position, aim)
			end
			created.Parent = head
			turn = created
		end
		movers = { hold :: Instance, turn :: Instance }
	end
	character:SetAttribute(TAIL_ATTRIBUTE, nil)
	local run = (character:GetAttribute("GumGatlingRun") or 0) + 1
	character:SetAttribute("GumGatlingRun", run)

	local elapsed = 0
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= SEND_INTERVAL then
			elapsed = 0
			local aim = getAim()
			if aim then
				abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
			end
		end
	end)

	return function()
		connection:Disconnect()
		showArms()

		-- The movers outlive the stream until its last punch is over, unless a new
		-- stream has taken them over by then.
		local tail = character:GetAttribute(TAIL_ATTRIBUTE)
		local remaining = if type(tail) == "number" then math.max(tail - os.clock(), 0) else 0
		task.delay(remaining, function()
			if character:GetAttribute("GumGatlingRun") ~= run then
				return
			end
			for _, mover in movers do
				mover:Destroy()
			end
		end)
	end
end
