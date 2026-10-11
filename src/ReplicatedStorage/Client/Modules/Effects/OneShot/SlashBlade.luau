--!strict
--[[
	Slash fruit - a flying blade: the claw cut of Slash Claws, the slash of Slash Dismantle
	or the heavy slash of Slash Cleave. Cosmetic copy of a blade the server sweeps in a
	straight line (it goes through walls, as the legacy part did).

	params: { Kind: "Claw" | "Dismantle" | "Cleave", Variant: number, Direction: Vector3,
	          Speed: number, Lifetime: number, Scale: number, Haki: boolean,
	          Colors: string, Caster: Model }
	Templates (ReplicatedStorage.Assets.Models.Fruits.Slash):
	- Claw:      Power1.ClawCuts.ClawCut<Variant>; sized 7.98 x 19.44 x 11.44 times Scale,
	             as the legacy script did, whatever the authored size.
	- Dismantle: one of the meshes of Power2 (sorted by name, picked by Variant), authored
	             size times Scale.
	- Cleave:    Power3.Cleave, authored size times Scale.

	The models are authored sideways: their X axis is the flight direction.
	First fruit color on the blade; dark with armament haki.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local CLAW_SIZE = Vector3.new(7.9795, 19.4445, 11.4445)
local SIDEWAYS = CFrame.Angles(0, math.rad(90), 0)
local MAX_DIMENSION = 2048

local function findTemplate(kind: any, variant: number): BasePart?
	local template: Instance? = nil
	if kind == "Claw" then
		template = EffectAssets.FindFruit("Slash", "Power1", "ClawCuts", `ClawCut{variant}`)
	elseif kind == "Cleave" then
		template = EffectAssets.FindFruit("Slash", "Power3", "Cleave")
	elseif kind == "Dismantle" then
		local folder = EffectAssets.FindFruit("Slash", "Power2")
		if folder then
			local meshes: { Instance } = {}
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(meshes, child)
				end
			end
			-- Same order on every client, so everyone sees the same mesh.
			table.sort(meshes, function(a: Instance, b: Instance)
				return a.Name < b.Name
			end)
			if #meshes > 0 then
				template = meshes[(variant - 1) % #meshes + 1]
			end
		end
	end
	return if template and template:IsA("BasePart") then template else nil
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local speed = params.Speed
	local lifetime = params.Lifetime
	local scale = params.Scale
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(lifetime) ~= "number" or type(scale) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or speed <= 0 or lifetime <= 0 or scale <= 0 then
		return
	end

	local variant = if type(params.Variant) == "number" then math.max(1, math.floor(params.Variant)) else 1
	local template = findTemplate(params.Kind, variant)
	if not template then
		return
	end

	local blade = template:Clone()
	for _, descendant in blade:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end

	local size = (if params.Kind == "Claw" then CLAW_SIZE else template.Size) * scale
	blade.Size = Vector3.new(
		math.min(size.X, MAX_DIMENSION),
		math.min(size.Y, MAX_DIMENSION),
		math.min(size.Z, MAX_DIMENSION)
	)
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false

	local primary = EffectAssets.Colors(params.Colors, blade.Color, blade.Color)
	blade.Color = if params.Haki then HAKI_COLOR else primary

	local unit = direction.Unit
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local start = CFrame.lookAt(origin, origin + unit, up) * SIDEWAYS
	blade.CFrame = start
	blade.Parent = World.Effects()

	TweenService:Create(blade, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), {
		CFrame = start + unit * speed * lifetime,
	}):Play()
	Debris:AddItem(blade, lifetime)
end
