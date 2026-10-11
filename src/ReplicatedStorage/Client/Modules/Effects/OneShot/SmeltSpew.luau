--!strict
--[[
	Smelt fruit - Spew: the molten pool. Purely cosmetic; the server burns whoever is
	inside the same moving circle without any instance.

	origin: where the pool starts (the caster's feet).
	params: { Direction: Vector3 (flat unit), Travel: number, Length: number,
	          GrowTime: number, LingerTime: number, Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Smelt.Power3.SmeltSpew (a part).

	The pool lies on its side (the part's X axis points up), grows linearly to
	2 x Length/2 x Length while sliding Travel studs along Direction, lingers, then goes.
	It also goes when its caster dies, at the moment the server stops burning.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local THICKNESS = 2
local START_SIZE = Vector3.new(0.05, 0.05, 0.05)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local FLAT_ROTATION = CFrame.Angles(0, math.rad(180), math.rad(90))

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local travel = params.Travel
	local length = params.Length
	if typeof(direction) ~= "Vector3" or type(travel) ~= "number" or type(length) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or length <= 0 then
		return
	end
	local growTime: number = if type(params.GrowTime) == "number" then params.GrowTime else 5
	local lingerTime: number = if type(params.LingerTime) == "number" then params.LingerTime else 3

	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local fruit = fruits and fruits:FindFirstChild("Smelt")
	local folder = fruit and fruit:FindFirstChild("Power3")
	local template = folder and folder:FindFirstChild("SmeltSpew")
	if not template or not template:IsA("BasePart") then
		return
	end

	local pool = template:Clone()
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanQuery = false
	pool.CanTouch = false
	pool.Size = START_SIZE

	if params.Haki then
		pool.Color = HAKI_COLOR
	else
		local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
		if primary then
			pool.Color = primary
		end
	end

	local rotation = CFrame.lookAt(origin, origin + direction).Rotation * FLAT_ROTATION
	pool.CFrame = CFrame.new(origin) * rotation
	pool.Parent = World.Effects()

	TweenService:Create(pool, TweenInfo.new(growTime, Enum.EasingStyle.Linear), {
		Size = Vector3.new(THICKNESS, length / 2, length),
		CFrame = CFrame.new(origin + direction.Unit * travel) * rotation,
	}):Play()
	Debris:AddItem(pool, growTime + lingerTime)

	local caster = params.Caster
	local humanoid = if typeof(caster) == "Instance" then caster:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		local died = humanoid.Died:Connect(function()
			pool:Destroy()
		end)
		pool.Destroying:Once(function()
			died:Disconnect()
		end)
	end
end
