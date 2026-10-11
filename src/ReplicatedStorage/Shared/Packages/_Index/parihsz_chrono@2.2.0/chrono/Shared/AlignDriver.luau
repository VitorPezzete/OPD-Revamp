export type AlignDriver = {
	part: BasePart,
	container: Camera,
	driverPart: BasePart,
	alignPosition: AlignPosition,
	alignOrientation: AlignOrientation,
}

local IS_SERVER = game:GetService("RunService"):IsServer()

local CONTAINER_NAME = "__CHRONO_ALIGN"
local DRIVER_PART_NAME = "__CHRONO_ALIGN_PART"

local ROOT_PRIORITY = 127

local MAX_RESPONSIVENESS = 200



local AlignDriver = {}

local function Create(part: BasePart): AlignDriver
	local previous = part:FindFirstChild(CONTAINER_NAME)
	if previous then
		previous:Destroy()
	end

	local initCF = part.CFrame

	local container = Instance.new("Camera")
	container.Archivable = false
	container.Name = CONTAINER_NAME
	container.Parent = part

	local driverPart = Instance.new("Part")
	driverPart.Name = DRIVER_PART_NAME

	driverPart.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
	driverPart.Massless = false
	driverPart.RootPriority = ROOT_PRIORITY
	driverPart.Size = Vector3.zero
	driverPart.CanCollide = false
	driverPart.CanQuery = false
	driverPart.CanTouch = false
	driverPart.Transparency = if IS_SERVER then 0 else 1
	driverPart.Color = Color3.new(0, 1, 0)

	driverPart.CFrame = initCF
	driverPart.Parent = container

	local weld = Instance.new("Weld")
	weld.Name = "__CHRONO_ALIGN_WELD"
	weld.Part0 = driverPart
	weld.Part1 = part
	weld.Parent = container

	local attachment = Instance.new("Attachment")
	attachment.Name = "__CHRONO_ALIGN_ATTACHMENT"
	attachment.Parent = driverPart

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment

	alignPosition.ApplyAtCenterOfMass = false
	alignPosition.ReactionForceEnabled = false

	alignPosition.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	alignPosition.ForceLimitMode = Enum.ForceLimitMode.Magnitude

	alignPosition.MaxForce = math.huge
	alignPosition.MaxVelocity = math.huge
	alignPosition.Responsiveness = MAX_RESPONSIVENESS

	alignPosition.RigidityEnabled = true
	alignPosition.Position = initCF.Position
	alignPosition.Parent = driverPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment

	alignOrientation.AlignType = Enum.AlignType.AllAxes
	alignOrientation.PrimaryAxisOnly = false
	alignOrientation.ReactionTorqueEnabled = false
	alignOrientation.MaxTorque = math.huge
	alignOrientation.MaxAngularVelocity = math.huge
	alignOrientation.Responsiveness = MAX_RESPONSIVENESS
	alignOrientation.RigidityEnabled = true
	alignOrientation.CFrame = initCF.Rotation
	alignOrientation.Parent = driverPart

	part.CFrame = initCF

	return {
		part = part,
		container = container,
		driverPart = driverPart,
		alignPosition = alignPosition,
		alignOrientation = alignOrientation,
	}
end

local function Update(driver: AlignDriver, cframe: CFrame)
	driver.alignPosition.Position = cframe.Position
	driver.alignOrientation.CFrame = cframe.Rotation
end

local function Destroy(driver: AlignDriver)
	if driver.container then
		driver.container:Destroy()
	end
end

AlignDriver.Create = Create
AlignDriver.Update = Update
AlignDriver.Destroy = Destroy

return AlignDriver
