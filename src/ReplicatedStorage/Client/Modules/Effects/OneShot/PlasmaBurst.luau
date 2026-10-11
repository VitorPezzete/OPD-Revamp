--!strict
--[[
	Plasma fruit - Plasma Burst: three expanding flashes on the user and 15 bolts thrown
	40 studs in random directions.
	params: { Haki: boolean, Thickness: number, Colors: string, Caster: Model }

	Flash template: ReplicatedStorage.Assets.Models.Fruits.Plasma.Power3.PlasmaBurst (a
	part with a BillboardGui holding a "Background" image). Each copy rides the root for
	0.75 s while its billboard grows; they start 0.12 s apart.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.PlasmaBolt)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local DEFAULT_COLOR = Color3.fromRGB(221, 117, 255)
local FLASHES = 3
local FLASH_INTERVAL = 0.12
local FLASH_LIFE = 0.75
local FLASH_GROW_TIME = 0.25
-- The legacy tween target, kept as authored (scale and offset both 50).
local FLASH_SIZE = UDim2.new(50, 50, 50, 50)
local BOLTS = 15
local BOLT_LENGTH = 40
local BOLT_LIFE = 0.7

return function(origin: Vector3, params: { [string]: any }?)
	local options: { [string]: any } = params or {}
	local color = DEFAULT_COLOR
	if options.Haki then
		color = HAKI_COLOR
	elseif type(options.Colors) == "string" then
		color = FruitColor.Parse(options.Colors) or DEFAULT_COLOR
	end

	local caster = options.Caster
	local root = if typeof(caster) == "Instance" then caster:FindFirstChild("HumanoidRootPart") else nil
	local template = EffectAssets.FindFruit("Plasma", "Power3", "PlasmaBurst")

	if root and root:IsA("BasePart") and template and template:IsA("BasePart") then
		-- Typed copies: the closure below cannot rely on the narrowing above.
		local rootPart: BasePart, flashTemplate: BasePart = root, template
		task.spawn(function()
			for _ = 1, FLASHES do
				if not rootPart:IsDescendantOf(game) then
					break
				end

				local flash = flashTemplate:Clone()
				flash.Anchored = false
				flash.CanCollide = false
				flash.CanQuery = false
				flash.CanTouch = false
				flash.Massless = true
				flash.CFrame = rootPart.CFrame

				local weld = Instance.new("Weld")
				weld.Part0 = rootPart
				weld.Part1 = flash
				weld.Parent = flash

				local billboard = flash:FindFirstChildOfClass("BillboardGui")
				if billboard then
					local background = billboard:FindFirstChild("Background")
					if background and background:IsA("ImageLabel") then
						background.ImageColor3 = color
					end
					TweenService:Create(billboard, TweenInfo.new(FLASH_GROW_TIME, Enum.EasingStyle.Linear), {
						Size = FLASH_SIZE,
					}):Play()
				end

				flash.Parent = rootPart
				Debris:AddItem(flash, FLASH_LIFE)
				task.wait(FLASH_INTERVAL)
			end
		end)
	end

	for _ = 1, BOLTS do
		local start = if root and root:IsA("BasePart") then root.Position else origin
		local direction = Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
		if direction.Magnitude < 1 then
			direction = Vector3.yAxis
		end
		drawBolt(start, {
			Target = start + direction.Unit * BOLT_LENGTH,
			Color = color,
			Thickness = options.Thickness,
			Life = BOLT_LIFE,
			Shrink = BOLT_LIFE,
			Linear = true,
		})
		task.wait()
	end
end
