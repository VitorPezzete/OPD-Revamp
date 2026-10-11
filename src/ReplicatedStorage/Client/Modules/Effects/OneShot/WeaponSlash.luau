--!strict
--[[
	The slash thrown by a sword's special attack: a copy of the box the server sweeps
	along the aim (it goes through walls, as the legacy part did).

	Not purely cosmetic: the slash answers spatial queries (CanQuery), as the old game's
	part did. The aim ray lands on it, which is how Gum Rocket grabs a Kogatana slash - a
	bug of the old game that became a mechanic and stays. The server accepts such a point
	from its own record of the flight (Server.Modules.ThrownSlashes). It still collides
	with nothing and touches nothing.

	params: { Asset: string, Direction: Vector3, Speed: number, Lifetime: number,
	          Scale: number, Haki: boolean, Flare: boolean?, Caster: Model }
	Template: the part named Asset (DaggerSlash, YoruSlash, ...; legacy
	ServerStorage.OtherStuff.SwordSlashes), authored size times Scale (sword level / 500).
	Its X axis is the flight direction. Dark with armament haki; orange and burning for
	Roger in the hands of a Flare user ("Flare Fire" emitter of the template).
	Without the template a plain neon crescent is shown.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local SIDEWAYS = CFrame.Angles(0, math.rad(-90), 0)
local FLARE_COLOR = Color3.fromRGB(255, 128, 0)
local FALLBACK_SIZE = Vector3.new(2, 6, 12)
local CANDY_HAKI_TEXTURE = "rbxassetid://92214626822869"

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Direction) ~= "Vector3" then
		return
	end
	local direction: Vector3 = params.Direction.Unit
	local speed: number = params.Speed or 300
	local lifetime: number = params.Lifetime or 0.5
	local scale: number = params.Scale or 1

	local template = WeaponFx.FindAsset(tostring(params.Asset))
	local slash: BasePart
	if template and template:IsA("BasePart") then
		slash = template:Clone() :: BasePart
		WeaponFx.Neutralize(slash)
		slash.Size = template.Size * scale
	else
		slash = WeaponFx.Part({
			Size = FALLBACK_SIZE * scale,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(235, 235, 255),
			Transparency = 0.3,
		})
	end

	-- After Neutralize / WeaponFx.Part, which switch every query off (see the header).
	-- Only the slash itself: whatever else the template carries stays out of the way.
	slash.CanQuery = true

	if params.Haki then
		slash.Color = WeaponFx.HakiColor
		-- Legacy swapped the candy cane texture for a dark one under haki.
		local mesh = slash:FindFirstChild("CandyCaneKogatanaSlash")
		if mesh and mesh:IsA("SpecialMesh") then
			mesh.TextureId = CANDY_HAKI_TEXTURE
		elseif slash:IsA("MeshPart") and params.Asset == "CandyCaneKogatanaSlash" then
			(slash :: any).TextureID = CANDY_HAKI_TEXTURE
		end
	end
	if params.Flare then
		slash.Color = FLARE_COLOR
		local fire = slash:FindFirstChild("Flare Fire")
		if fire and fire:IsA("ParticleEmitter") then
			fire.Enabled = true
		end
	end

	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local facing = CFrame.lookAt(origin, origin + direction, up)
	slash.CFrame = facing * SIDEWAYS
	slash.Parent = World.Effects()

	WeaponFx.Tween(slash, lifetime, { CFrame = (facing + direction * speed * lifetime) * SIDEWAYS }, Enum.EasingStyle.Linear)
	Debris:AddItem(slash, lifetime + 0.05)
end
