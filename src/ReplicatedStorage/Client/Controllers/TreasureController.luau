--!strict
--[[
	The treasure compasses and devil fruit boxes in the local player's hands
	(TreasureService, FruitBoxService).

	Compass: using the held tool wakes it. Its needle turns towards the burial point the
	server stored on the tool (TreasureConfig.TargetAttribute) and, once the holder stands
	on it, the client tells the server so with no arguments: the server measures the
	distance itself. The compass sleeps again when it is put away.

	Box: using the held tool asks the server to open it, again with no arguments.

	The legacy tools did all of this in server scripts, a 0.1 s loop per compass in use.
	The loop now only exists here, on the holder's client, while a compass is awake. The
	legacy game had no interface or effect for either tool, so there is none.

	Tool parts used when present (legacy names): Handle, CompassArrow with a "Weld" whose
	Part0 is the handle.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local TreasureConfig = require(ReplicatedStorage.Shared.Configs.TreasureConfig)

local STEP = 0.1
-- Seconds between two "I have arrived" messages while standing on the treasure.
local ARRIVE_RETRY = 1.5
-- The needle stays visible this long after the compass is put away (legacy delay).
local SLEEP_DELAY = 0.5

local TreasureController = Knit.CreateController({
	Name = "TreasureController",
})

local TreasureService
local FruitBoxService

-- Tools already bound; the value tells whether a compass is awake.
local bound: { [Tool]: boolean } = {}

local function run(tool: Tool, radius: number)
	local player = Players.LocalPlayer
	local handle = tool:FindFirstChild("Handle")
	local arrow = tool:FindFirstChild("CompassArrow")
	local weld = arrow and arrow:FindFirstChild("Weld")
	local mount = if tool:GetAttribute(TreasureConfig.NeedleFlipAttribute) == true then math.rad(90) else -math.rad(90)

	if arrow and arrow:IsA("BasePart") then
		arrow.Transparency = 0
	end

	local nextArrive = 0
	while tool.Parent ~= nil and tool.Parent == player.Character do
		-- Read every step: the server sets it when the tool is first carried.
		local target = tool:GetAttribute(TreasureConfig.TargetAttribute)
		if typeof(target) == "Vector3" then
			if handle and handle:IsA("BasePart") and weld and weld:IsA("Weld") and weld.Part0 then
				-- Needle: the angle between where the handle looks and where the treasure is.
				local offset = target - weld.Part0.Position
				local look = handle.CFrame.LookVector
				local angle = math.atan2(-look.Z, look.X) - math.atan2(-offset.Z, offset.X)
				weld.C1 = CFrame.new(-0.08, 0, 0) * CFrame.Angles(angle, 0, 0) * CFrame.Angles(mount, 0, 0)
			end

			local root = (tool.Parent :: Model).PrimaryPart
			local now = os.clock()
			if root and now >= nextArrive and (root.Position - target).Magnitude <= radius then
				nextArrive = now + ARRIVE_RETRY
				TreasureService.Arrive:Fire()
			end
		end
		task.wait(STEP)
	end

	task.wait(SLEEP_DELAY)
	if arrow and arrow:IsA("BasePart") and arrow.Parent then
		arrow.Transparency = 1
	end
end

local function bindCompass(tool: Tool, radius: number)
	tool.Activated:Connect(function()
		if bound[tool] ~= false then
			return
		end
		bound[tool] = true
		run(tool, radius)
		if bound[tool] ~= nil then
			bound[tool] = false
		end
	end)
end

local function bindBox(tool: Tool)
	tool.Activated:Connect(function()
		FruitBoxService.Open:Fire()
	end)
end

local function check(child: Instance)
	if not child:IsA("Tool") or bound[child] ~= nil then
		return
	end

	local compass = TreasureConfig.Compasses[child.Name]
	if compass then
		bindCompass(child, compass.ArrivalRadius)
	elseif TreasureConfig.Boxes[child.Name] then
		bindBox(child)
	else
		return
	end

	local tool = child
	bound[tool] = false
	tool.Destroying:Once(function()
		bound[tool] = nil
	end)
end

-- The watched container goes away with its connection (respawn).
local function watch(container: Instance)
	container.ChildAdded:Connect(check)
	for _, child in container:GetChildren() do
		check(child)
	end
end

function TreasureController:KnitStart()
	TreasureService = Knit.GetService("TreasureService")
	FruitBoxService = Knit.GetService("FruitBoxService")

	local player = Players.LocalPlayer
	-- Tools are handed into the backpack, or straight into the hand when picked up from
	-- the ground. A new backpack and a new character come with every respawn.
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	player.CharacterAdded:Connect(watch)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(backpack)
	end
	if player.Character then
		watch(player.Character)
	end
end

return TreasureController
