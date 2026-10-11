--!strict
--[[
	Blood fruit - Blood Convergence: the lance of blood. Purely cosmetic; the server
	casts the same origin / direction / speed without any instance. Like the legacy part
	(not collidable), the lance pierces characters and walls alike and flies its whole
	range unless the server ends it.

	Two messages share this effect:
	  launch  { Shot: number, Direction: Vector3 (unit), Speed: number, Range: number,
	            Width: number, Concentrate: boolean, Colors: string }
	  end     { Shot: number, EndIn: number }   the lance hit its first character: it is
	          gone EndIn seconds later, as the legacy one was.
	Both carry Caster; Shot tells the lances of one caster apart.

	Template: ReplicatedStorage.Assets.Models.Fruits.Blood.Power2.Pierce (an invisible
	part; the lance is the emitters under its Attachment, all of them with Concentrate).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LENGTH = 25

-- Lances in flight, per caster character and shot number.
local live: { [Instance]: { [number]: BasePart } } = {}

local function forget(caster: Instance, shot: number, lance: BasePart)
	local shots = live[caster]
	if shots and shots[shot] == lance then
		shots[shot] = nil
		if next(shots) == nil then
			live[caster] = nil
		end
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local caster = params.Caster
	local shot = params.Shot

	if type(params.EndIn) == "number" then
		local shots = if typeof(caster) == "Instance" then live[caster] else nil
		local lance = if shots and type(shot) == "number" then shots[shot] else nil
		if lance then
			task.delay(math.max(params.EndIn, 0), lance.Destroy, lance)
		end
		return
	end

	local direction = params.Direction
	local speed = params.Speed
	local range = params.Range
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(range) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or speed <= 0 or range <= 0 then
		return
	end
	local width: number = if type(params.Width) == "number" then params.Width else 3

	local template = EffectAssets.FindFruit("Blood", "Power2", "Pierce")
	if not template or not template:IsA("BasePart") then
		return
	end

	local unit = direction.Unit
	local distance = range
	local duration = distance / speed

	local lance = template:Clone()
	lance.Anchored = true
	lance.CanCollide = false
	lance.CanQuery = false
	lance.CanTouch = false
	lance.Size = Vector3.new(width, width, LENGTH)

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local attachment = lance:FindFirstChild("Attachment")
	for _, descendant in lance:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			if primary and secondary and attachment and descendant:IsDescendantOf(attachment) then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
			if params.Concentrate and attachment and descendant:IsDescendantOf(attachment) then
				descendant.Enabled = true
			end
		end
	end

	local rotation = CFrame.lookAt(origin, origin + unit).Rotation
	lance.CFrame = CFrame.new(origin) * rotation
	lance.Parent = World.Effects()

	TweenService:Create(lance, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(origin + unit * distance) * rotation,
	}):Play()
	Debris:AddItem(lance, duration + 0.1)

	if typeof(caster) == "Instance" and type(shot) == "number" then
		local casterInstance: Instance, shotNumber: number = caster, shot
		local shots = live[casterInstance]
		if not shots then
			shots = {}
			live[casterInstance] = shots
		end
		shots[shotNumber] = lance
		lance.Destroying:Once(function()
			forget(casterInstance, shotNumber, lance)
		end)
	end
end
