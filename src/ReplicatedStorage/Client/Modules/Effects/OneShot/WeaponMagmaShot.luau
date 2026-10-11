--!strict
--[[
	Magma Gun: one magma ball, for the normal shot (full size, 300 studs/s) and for each
	of the scattered shots of the special (60% size, 450 studs/s).

	The ball is the legacy bullet template ("MagmaBu", ReplicatedStorage.Resources in the
	old place, searched by name under Assets.Models here). Without it a ball of glowing
	magma is drawn instead, so the gun never looks like it fires an ordinary bullet.

	It flies along the same line the server casts. As the legacy part (CanCollide false,
	reacting to characters only) it goes through walls and stops at the first character
	that is not the shooter.
	params: { Direction: Vector3, Speed: number, Range: number, Scale: number?,
	          Caster: Model? }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

-- Stand-in ball, used only when the template is missing (its real size is not known).
local FALLBACK_SIZE = 2
local FALLBACK_COLOR = Color3.fromRGB(255, 89, 0)
local FALLBACK_CORE = Color3.fromRGB(255, 170, 0)

-- Studs to the first character on the line that is not the shooter, or `range`.
local function distanceToCharacter(origin: Vector3, direction: Vector3, range: number, caster: Instance?): number
	local alive = World.AliveRoot()
	if not alive then
		return range
	end

	local characters: { Instance } = {}
	for _, kind in alive:GetChildren() do
		for _, character in kind:GetChildren() do
			if character ~= caster then
				table.insert(characters, character)
			end
		end
	end
	if #characters == 0 then
		return range
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = characters
	local result = Workspace:Raycast(origin, direction * range, params)
	return if result then result.Distance else range
end

local function fallbackBall(scale: number, life: number): BasePart
	local size = FALLBACK_SIZE * scale
	local ball = WeaponFx.Part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Material = Enum.Material.Neon,
		Color = FALLBACK_COLOR,
	}, life, World.Effects())

	local light = Instance.new("PointLight")
	light.Color = FALLBACK_COLOR
	light.Range = 4 * size
	light.Brightness = 2
	light.Parent = ball

	local fire = Instance.new("Fire")
	fire.Color = FALLBACK_COLOR
	fire.SecondaryColor = FALLBACK_CORE
	fire.Size = size * 1.5
	fire.Heat = 0
	fire.Parent = ball
	return ball
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Direction) ~= "Vector3" or params.Direction.Magnitude < 1e-4 then
		return
	end
	local direction: Vector3 = params.Direction.Unit
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 300
	local range: number = if type(params.Range) == "number" then params.Range else 750
	local scale: number = if type(params.Scale) == "number" then params.Scale else 1
	local caster: Instance? = if typeof(params.Caster) == "Instance" then params.Caster else nil

	local distance = distanceToCharacter(origin, direction, range, caster)
	local duration = distance / speed

	local template = WeaponFx.FindAsset("MagmaBu")
	local bullet: BasePart
	if template and template:IsA("BasePart") then
		bullet = template:Clone() :: BasePart
		WeaponFx.Neutralize(bullet)
		bullet.Size = template.Size * scale
		bullet.Parent = World.Effects()
		Debris:AddItem(bullet, duration + 0.05)
	else
		bullet = fallbackBall(scale, duration + 0.05)
	end

	local facing = CFrame.lookAt(origin, origin + direction)
	bullet.CFrame = facing
	WeaponFx.Tween(bullet, duration, { CFrame = facing + direction * distance }, Enum.EasingStyle.Linear)
end
