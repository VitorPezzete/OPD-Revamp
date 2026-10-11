--!strict
--[[
	One spawned boat.

	Driving is simulated by the driver's client (BoatController): whoever sits in the
	VehicleSeat gets network ownership of the assembly and steers its BodyVelocity /
	BodyGyro locally. The server only hands ownership over, takes it back when the seat
	empties, and audits how fast the boat really moves (Audit, called from BoatService's
	single loop).
]]
local Players = game:GetService("Players")

local Boat = {}
Boat.__index = Boat

-- Tolerance over the seat's MaxSpeed before a reading counts as a violation.
local SPEED_MARGIN_SCALE = 1.3
local SPEED_MARGIN_FLAT = 12
local STRIKES_TO_EJECT = 2
local SEAT_LOCK_SECONDS = 3
local FALLBACK_MAX_SPEED = 60

export type Boat = typeof(setmetatable(
	{} :: {
		Owner: Player,
		Model: Model,
		Seat: BasePart,
		Driver: Player?,
		MaxSpeed: number,

		_velocity: BodyVelocity?,
		_gyro: BodyGyro?,
		_lastPosition: Vector3,
		_lastAudit: number,
		_strikes: number,
		_connection: RBXScriptConnection?,
	},
	Boat
))

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Upright CFrame at the origin facing where the seat faces.
local function yawOf(cframe: CFrame): CFrame
	local look = flatten(cframe.LookVector)
	if look.Magnitude < 1e-3 then
		return CFrame.identity
	end
	return CFrame.lookAt(Vector3.zero, look)
end

function Boat.new(owner: Player, model: Model, seat: BasePart): Boat
	local self = setmetatable({
		Owner = owner,
		Model = model,
		Seat = seat,
		Driver = nil :: Player?,
		MaxSpeed = if seat:IsA("VehicleSeat") then seat.MaxSpeed else FALLBACK_MAX_SPEED,

		_velocity = seat:FindFirstChildOfClass("BodyVelocity"),
		_gyro = seat:FindFirstChildOfClass("BodyGyro"),
		_lastPosition = seat.Position,
		_lastAudit = os.clock(),
		_strikes = 0,
		_connection = nil :: RBXScriptConnection?,
	}, Boat)

	if seat:IsA("VehicleSeat") or seat:IsA("Seat") then
		self._connection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:_onOccupantChanged()
		end)
	end
	-- Server-owned until someone takes the helm (`model` is already in the world).
	self:_setOwner(nil)
	return self
end

function Boat._setOwner(self: Boat, player: Player?)
	-- Throws on anchored assemblies; a boat that cannot change hands just stays put.
	pcall(function()
		self.Seat:SetNetworkOwner(player)
	end)
end

-- Stops the boat where it is, facing where it faces. The driver's client changed the
-- movers only locally, so the server copies still hold the values of the last stop.
function Boat.Halt(self: Boat)
	if self._velocity then
		self._velocity.Velocity = Vector3.zero
	end
	if self._gyro then
		self._gyro.CFrame = yawOf(self.Seat.CFrame)
	end
	self.Seat.AssemblyLinearVelocity = Vector3.zero
end

-- Points the boat at a world yaw (degrees); the gyro turns it there, as in the legacy shops.
function Boat.Face(self: Boat, yawDegrees: number)
	if self._gyro then
		self._gyro.CFrame = CFrame.Angles(0, math.rad(yawDegrees), 0)
	end
end

function Boat._onOccupantChanged(self: Boat)
	local occupant = (self.Seat :: any).Occupant :: Humanoid?
	local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent :: any)

	self.Driver = driver
	self._strikes = 0
	self._lastPosition = self.Seat.Position
	self._lastAudit = os.clock()

	if driver then
		self:_setOwner(driver)
	else
		-- Explicit server ownership: automatic ownership would hand the boat to whoever
		-- stands closest, still running their own copy of the movers.
		self:_setOwner(nil)
		self:Halt()
	end
end

function Boat._eject(self: Boat)
	local seat = self.Seat
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end

	-- Keeps the offender from sitting straight back down.
	if seat:IsA("VehicleSeat") then
		seat.Disabled = true
		task.delay(SEAT_LOCK_SECONDS, function()
			if seat.Parent then
				seat.Disabled = false
			end
		end)
	end

	self.Driver = nil
	self:_setOwner(nil)
	self:Halt()
end

-- Compares what the boat did since the last audit with what its seat allows.
-- Horizontal only: falling off a wave is not speeding. Returns true when the driver
-- was thrown out.
function Boat.Audit(self: Boat, now: number): boolean
	local position = self.Seat.Position
	local elapsed = now - self._lastAudit
	local travelled = flatten(position - self._lastPosition).Magnitude
	self._lastPosition = position
	self._lastAudit = now

	if not self.Driver or elapsed <= 0 then
		return false
	end

	local limit = self.MaxSpeed * SPEED_MARGIN_SCALE + SPEED_MARGIN_FLAT
	local reported = flatten(self.Seat.AssemblyLinearVelocity).Magnitude
	if reported <= limit and travelled / elapsed <= limit then
		self._strikes = 0
		return false
	end

	self._strikes += 1
	if self._strikes < STRIKES_TO_EJECT then
		return false
	end
	self:_eject()
	return true
end

function Boat.Destroy(self: Boat)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self.Model:Destroy()
end

return Boat
