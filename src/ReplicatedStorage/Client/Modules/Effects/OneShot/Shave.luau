--!strict
--[[
	Shave (MovementService): the flash a character leaves where it vanished and where
	it reappears. origin = where it left from.

	params:
		Caster: Model            the character
		Destination: Vector3     where it landed
		Rotation: CFrame         its orientation when it left
		Rumble: boolean          Rumble fruit users travel as lightning instead
		Colors: string           fruit color string of the Rumble fruit, or "None"
		SnowStatue: string?      set (fruit colors of the Snow fruit) when a Snow user shaved
		                         inside its own globe: a snow copy of the body stays behind

	Normal: a flash billboard 4 studs above the old spot and on the character for 0.175 s,
	with the vanish sound. The billboard is UI.Components.ShaveFlash, or the legacy
	ShaveEffect layout while the legacy interface is mounted (UI.Util.Interface).
	Rumble: a light on each body part for 1 s, twenty sparks around the character and the
	Electricity sound.
	Snow statue: head, torso and limbs copied in place, snow white (or the fruit's first
	color), removed after 5 s.

	The legacy server built all of this itself: parts, lights, billboards and sounds
	parented into the character and the workspace on every shave.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Interface = require(ReplicatedStorage.Client.UI.Util.Interface)
local ShaveFlash = require(ReplicatedStorage.Client.UI.Components.ShaveFlash)

local startSparks = require(script.Parent.RumbleSparks)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local FLASH_SECONDS = 0.175
local FLASH_HEIGHT = 4
local VANISH_SOUND = "rbxassetid://303967360"
local SOUND_LIFETIME = 3

-- BrickColor "Toothpaste", the default of every Rumble light.
local RUMBLE_COLOR = Color3.fromRGB(0, 255, 255)
local LIGHT_NAME = "RumbleShave"
local LIGHT_SECONDS = 1
local LIGHT_RANGE = 4
local LIGHT_BRIGHTNESS = 3
local SPARK_COUNT = 20
local SPARK_INTERVAL = 0.0267
local SPARK_RANGE = 5
local SPARK_LIFE = 0.5

local SNOW_COLOR = Color3.fromRGB(248, 248, 248)
local STATUE_SECONDS = 5

local function playSound(parent: Instance, id: string, volume: number, speed: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, SOUND_LIFETIME)
end

local function buildFlash(scope: any, adornee: Instance)
	if Interface.getStyle() == "Divine" then
		local flash = ShaveFlash(scope, { Duration = FLASH_SECONDS })
		flash.Adornee = adornee
		flash.Parent = adornee
		return
	end

	local layout = ReplicatedStorage.Client.UI.Legacy.Layouts:FindFirstChild("ShaveEffect")
	if not layout or not layout:IsA("ModuleScript") then
		return
	end

	local billboard = (require :: any)(layout)(scope)
	if typeof(billboard) == "Instance" and billboard:IsA("BillboardGui") then
		billboard.Adornee = adornee
		billboard.Parent = adornee
	end
end

local function playFlash(origin: Vector3, root: BasePart?)
	local scope = Fusion.scoped(Fusion)

	local anchor = Instance.new("Attachment")
	anchor.Name = "ShaveOrigin"
	anchor.WorldPosition = origin + Vector3.new(0, FLASH_HEIGHT, 0)
	anchor.Parent = Workspace.Terrain
	table.insert(scope, anchor)

	buildFlash(scope, anchor)
	if root then
		buildFlash(scope, root)
		playSound(root, VANISH_SOUND, 1)
	else
		playSound(anchor, VANISH_SOUND, 1)
	end

	task.delay(FLASH_SECONDS, function()
		Fusion.doCleanup(scope)
	end)
end

local function playRumble(caster: Model?, root: BasePart?, destination: Vector3, colors: any)
	local primary = FruitColor.Parse(if type(colors) == "string" then colors else "")
	local color = primary or RUMBLE_COLOR

	if caster then
		for _, partName in BODY_PARTS do
			local part = caster:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				local previous = part:FindFirstChild(LIGHT_NAME)
				if previous then
					previous:Destroy()
				end

				local light = Instance.new("PointLight")
				light.Name = LIGHT_NAME
				light.Range = LIGHT_RANGE
				light.Brightness = LIGHT_BRIGHTNESS
				light.Color = color
				light.Parent = part
				Debris:AddItem(light, LIGHT_SECONDS)
			end
		end
	end

	startSparks(destination, {
		Part = root,
		Count = SPARK_COUNT,
		Interval = SPARK_INTERVAL,
		Range = SPARK_RANGE,
		-- The legacy sparks reached half as far below the root as above it.
		Floor = -0.5,
		Life = SPARK_LIFE,
		Thickness = 0.2,
		Color = color,
	})

	local definition = (SoundConfig :: any).SFX.Elemental.Rumble.Electricity
	if definition and root then
		playSound(root, definition.Id, definition.Volume, definition.Speed)
	end
end

-- A frozen copy of the body where the character stood, rebuilt from its current pose.
local function leaveStatue(caster: Model, root: BasePart, origin: Vector3, rotation: any, colors: string)
	local primary = FruitColor.Parse(colors)
	local color = primary or SNOW_COLOR
	local departure = CFrame.new(origin) * (if typeof(rotation) == "CFrame" then rotation.Rotation else root.CFrame.Rotation)

	local statue = Instance.new("Model")
	statue.Name = "SnowStatue"
	for _, partName in BODY_PARTS do
		local part = caster:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- Cloned for its shape (the head's mesh); everything else on it is dropped.
			local copy = part:Clone()
			if not copy then
				continue
			end
			for _, child in copy:GetChildren() do
				if not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			copy.Transparency = 0
			copy.Color = color
			copy.Material = Enum.Material.Snow
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanTouch = false
			copy.CanQuery = false
			copy.CastShadow = false
			copy.CFrame = departure * root.CFrame:ToObjectSpace(part.CFrame)
			copy.Parent = statue
		end
	end
	statue.Parent = World.Effects()
	Debris:AddItem(statue, STATUE_SECONDS)
end

return function(origin: Vector3, params: { [string]: any }?)
	local options: { [string]: any } = params or {}

	local caster: Model? = if typeof(options.Caster) == "Instance" and options.Caster:IsA("Model") then options.Caster else nil
	local foundRoot = caster and caster:FindFirstChild("HumanoidRootPart")
	local root: BasePart? = if foundRoot and foundRoot:IsA("BasePart") then foundRoot else nil
	local destination: Vector3 = if typeof(options.Destination) == "Vector3" then options.Destination else origin

	if caster and root and type(options.SnowStatue) == "string" then
		leaveStatue(caster, root, origin, options.Rotation, options.SnowStatue)
	end

	if options.Rumble == true then
		playRumble(caster, root, destination, options.Colors)
	else
		playFlash(origin, root)
	end
end
