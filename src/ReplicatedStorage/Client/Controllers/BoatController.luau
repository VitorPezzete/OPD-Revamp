--!strict
--[[
	Drives the boat the local player is steering.

	Sitting in a boat's VehicleSeat gives this client network ownership of the boat
	(BoatService), so the throttle / steer of the seat are turned into the boat's
	BodyVelocity and BodyGyro here, every frame, only while seated. The legacy game ran
	that loop on the server for every boat, occupied or not.

	The numbers are the legacy ones per second (BoatConfig); top speed is the seat's own
	MaxSpeed. The server audits the resulting speed, so editing them here only gets the
	driver thrown out of the seat.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local BoatConfig = require(ReplicatedStorage.Shared.Configs.BoatConfig)
local World = require(ReplicatedStorage.Shared.Util.World)

local BoatController = Knit.CreateController({
	Name = "BoatController",
})

local localPlayer = Players.LocalPlayer
local stopDriving: (() -> ())? = nil

local function approach(value: number, target: number, step: number): number
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

local function isBoatSeat(seat: Instance?): boolean
	local folder = World.RuntimeFolder(BoatConfig.FolderName)
	return seat ~= nil
		and seat:IsA("VehicleSeat")
		and seat.Name == BoatConfig.SeatName
		and folder ~= nil
		and seat:IsDescendantOf(folder)
end

local function drive(seat: VehicleSeat)
	local velocity = seat:FindFirstChildOfClass("BodyVelocity")
	local gyro = seat:FindFirstChildOfClass("BodyGyro")
	if not velocity or not gyro then
		return
	end

	-- Signed speed along the bow; starts from whatever the boat is doing.
	local speed = seat.AssemblyLinearVelocity:Dot(seat.CFrame.LookVector)

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		-- The boat was removed under the driver (replaced, owner left).
		if not seat:IsDescendantOf(Workspace) then
			connection:Disconnect()
			return
		end

		local maxSpeed = seat.MaxSpeed
		local throttle = seat.Throttle
		if throttle > 0 then
			if speed < maxSpeed then
				speed = math.min(speed + BoatConfig.Acceleration * deltaTime, maxSpeed)
			end
		elseif throttle < 0 then
			if speed > -maxSpeed then
				speed = math.max(speed - BoatConfig.ReverseAcceleration * deltaTime, -maxSpeed)
			end
		else
			speed = approach(speed, 0, BoatConfig.Deceleration * deltaTime)
		end
		velocity.Velocity = seat.CFrame.LookVector * speed

		local steer = seat.Steer
		if steer ~= 0 then
			gyro.CFrame *= CFrame.Angles(0, -math.rad(BoatConfig.TurnRate) * steer * deltaTime, 0)
		else
			gyro.CFrame = seat.CFrame
		end
	end)

	stopDriving = function()
		connection:Disconnect()
		-- These were only changed on this client; put them back to rest so this copy
		-- never pushes the boat again if ownership comes back without a driver.
		if velocity.Parent then
			velocity.Velocity = Vector3.zero
		end
	end
end

local function onSeated(active: boolean, seat: Instance?)
	if stopDriving then
		stopDriving()
		stopDriving = nil
	end
	if active and isBoatSeat(seat) then
		drive(seat :: VehicleSeat)
	end
end

local function onCharacterAdded(character: Model)
	onSeated(false, nil)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Seated:Connect(onSeated)
		humanoid.Died:Connect(function()
			onSeated(false, nil)
		end)
	end
end

function BoatController:IsDriving(): boolean
	return stopDriving ~= nil
end

function BoatController:KnitStart()
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if localPlayer.Character then
		task.spawn(onCharacterAdded, localPlayer.Character)
	end
end

return BoatController
