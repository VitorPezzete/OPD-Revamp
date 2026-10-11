--!strict
--[[
	Paw fruit - Spatial Repulsion: what is left where a character was repelled from, and
	the bubble around it where it arrived.

	params, Mode = "Self" (origin = where the user was):
		{ Colors, Caster }
	params, Mode = "Group" (origin = where the user was):
		{ Moved: { { Model: Model, Position: Vector3 } }, Destination: CFrame, Colors }

	For each character moved, as in the source: one "Repel" particle (first fruit color)
	on an attachment at the spot it left, which is removed 0.2 s later, and one "Bubble"
	particle (second fruit color) on its root for 0.5 s. The "Collision" sound plays on
	the user's root (Self) or at the destination (Group), cut after 0.9 s.
	Emitters: Effects.SpatialRepulsionSelf.Particles.
]]
local Debris = game:GetService("Debris")

local PawFx = require(script.Parent.Parent.Util.PawFx)

local GROUP = "SpatialRepulsionSelf"
local REPEL_SECONDS = 0.2
local BUBBLE_SECONDS = 0.5
local SOUND_SECONDS = 0.9

local function rootOf(model: any): BasePart?
	if typeof(model) ~= "Instance" then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function repel(model: any, from: Vector3, primary: Color3?, secondary: Color3?): BasePart?
	local repelParticle = PawFx.Emitter(GROUP, "Repel", primary)
	if repelParticle then
		repelParticle.Parent = PawFx.Anchor(CFrame.new(from), REPEL_SECONDS)
		repelParticle:Emit(1)
	end

	local root = rootOf(model)
	local bubble = if root then PawFx.Emitter(GROUP, "Bubble", secondary) else nil
	if root and bubble then
		bubble.Parent = root
		bubble:Emit(1)
		Debris:AddItem(bubble, BUBBLE_SECONDS)
	end
	return root
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local primary, secondary = PawFx.Colors(params.Colors)

	if params.Mode == "Group" then
		local moved = params.Moved
		if type(moved) == "table" then
			for _, entry in moved do
				if type(entry) == "table" and typeof(entry.Position) == "Vector3" then
					repel(entry.Model, entry.Position, primary, secondary)
				end
			end
		end
		local destination = params.Destination
		if typeof(destination) == "CFrame" then
			PawFx.SoundAt("Collision", destination.Position, SOUND_SECONDS)
		end
		return
	end

	local root = repel(params.Caster, origin, primary, secondary)
	if root then
		PawFx.Sound("Collision", root, SOUND_SECONDS)
	end
end
