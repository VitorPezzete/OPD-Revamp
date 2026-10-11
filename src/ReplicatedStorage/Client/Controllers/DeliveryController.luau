--!strict
--[[
	Local side of Merlin's deliveries.

	A package tool carries its destination as the "DeliveryTarget" attribute. Using the
	held package toggles its guiding arrow (the tool's "Bit" part, turned on its weld
	towards the destination); while the arrow is out and the character reaches the
	addressee, the controller asks the server to deliver. The server checks the distance
	itself, so this only decides when to ask.

	Also counts down Merlin's cooldown on the billboard above his head, from the end time
	the server publishes as a player attribute (the legacy server fired a remote every
	second per player for this).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)

local MERLIN = FishingConfig.Merlin
local TARGET_ATTRIBUTE = "DeliveryTarget"
local COOLDOWN_ATTRIBUTE = "MerlinCooldownEnd"
local ARROW_OFFSET = CFrame.new(0, -1.2, 0)
local ARROW_TURN = CFrame.Angles(0, math.rad(90), 0)
local DELIVER_RETRY = 1

local DeliveryController = Knit.CreateController({
	Name = "DeliveryController",
})

local MerlinService

local localPlayer = Players.LocalPlayer
local guiding: RBXScriptConnection? = nil
local lastAttempt = 0
local countdown = 0

local function stopGuiding(tool: Tool?)
	if guiding then
		guiding:Disconnect()
		guiding = nil
	end
	local arrow = tool and tool:FindFirstChild("Bit")
	if arrow and arrow:IsA("BasePart") then
		arrow.Transparency = 1
	end
end

local function startGuiding(tool: Tool, target: Vector3)
	local arrow = tool:FindFirstChild("Bit")
	local weld = arrow and arrow:FindFirstChildWhichIsA("JointInstance")
	local handle = tool:FindFirstChild("Handle")
	if arrow and arrow:IsA("BasePart") then
		arrow.Transparency = 0
	end

	guiding = RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		local root = character and character.PrimaryPart
		if not root or tool.Parent ~= character then
			stopGuiding(tool)
			return
		end

		if weld and (weld :: any).Part0 and handle and handle:IsA("BasePart") then
			local joint = weld :: any
			local toTarget = target - joint.Part0.Position
			local look = handle.CFrame.LookVector
			local yaw = math.atan2(-look.Z, look.X) - math.atan2(-toTarget.Z, toTarget.X)
			joint.C1 = ARROW_OFFSET * CFrame.Angles(0, yaw, 0) * ARROW_TURN
		end

		local now = os.clock()
		if (root.Position - target).Magnitude <= MERLIN.DeliveryRange and now - lastAttempt >= DELIVER_RETRY then
			lastAttempt = now
			task.spawn(function()
				MerlinService:Deliver()
			end)
		end
	end)
end

local function watchCharacter(character: Model)
	local bound: { [Instance]: boolean } = {}
	local function bind(child: Instance)
		if not child:IsA("Tool") or bound[child] or typeof(child:GetAttribute(TARGET_ATTRIBUTE)) ~= "Vector3" then
			return
		end
		bound[child] = true

		child.Activated:Connect(function()
			if guiding then
				stopGuiding(child)
			else
				startGuiding(child, child:GetAttribute(TARGET_ATTRIBUTE) :: Vector3)
			end
		end)
		child.Unequipped:Connect(function()
			stopGuiding(child)
		end)
	end

	character.ChildAdded:Connect(bind)
	for _, child in character:GetChildren() do
		bind(child)
	end
end

-- "59".."1" above Merlin while he has nothing new for this player.
local function showCooldown()
	countdown += 1
	local id = countdown

	local merchants = World.Merchants()
	local merchant = merchants and merchants:FindFirstChild(MERLIN.Merchant)
	local billboard = merchant and merchant:FindFirstChild("BillboardGui", true)
	local label = billboard and billboard:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		return
	end

	while countdown == id do
		local readyAt = localPlayer:GetAttribute(COOLDOWN_ATTRIBUTE)
		local remaining = if type(readyAt) == "number" then math.ceil(readyAt - Workspace:GetServerTimeNow()) else 0
		if remaining <= 0 then
			label.Text = ""
			return
		end
		label.Text = tostring(remaining)
		task.wait(1)
	end
end

function DeliveryController:KnitStart()
	MerlinService = Knit.GetService("MerlinService")

	localPlayer.CharacterAdded:Connect(function(character: Model)
		stopGuiding(nil)
		watchCharacter(character)
	end)
	if localPlayer.Character then
		watchCharacter(localPlayer.Character)
	end

	localPlayer:GetAttributeChangedSignal(COOLDOWN_ATTRIBUTE):Connect(function()
		task.spawn(showCooldown)
	end)
	task.spawn(showCooldown)
end

return DeliveryController
