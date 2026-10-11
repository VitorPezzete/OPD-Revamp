--!strict
--[[
	Gravity fruit - Crushing Force, while the owner holds the key: a flat see-through
	cylinder around the user showing the area the release would crush, growing with the
	charge. Owner only, as in the legacy game (the part lived in the LocalScript).

	Status value: "<B at full charge>|<seconds to full charge>|<fruit color string>".
	Template: ReplicatedStorage.Assets.Models.Fruits._Shared.GravityCrush (a Cylinder
	with six faint Textures; the copy in Fruits.Gravity.Power4 is used without it).

	With c = charge / 300 (at least 4 / 300) and B = <B at full charge> * c, the cylinder
	is 0.5 * B high and 2.5 * B across, centred on the root: the server's hit area. The
	charge is counted from the moment the status appears, over the seconds the server
	sends: the legacy client counted 37.5 per second against the server's 40, so its ring
	ran a little behind the real area, and it still does.

	On release the cylinder stays where it is and fades out in half a second.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local MIN_CHARGE = 4 / 300
-- Height and diameter per unit of B; the cylinder's axis is its X.
local SHAPE = Vector3.new(0.5, 2.5, 2.5)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local RELEASE_TRANSPARENCY = 0.8
local FADE_TIME = 0.5

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local fullSize = tonumber(fields[1])
	local fullSeconds = tonumber(fields[2])
	local template = EffectAssets.FindFruit("_Shared", "GravityCrush")
		or EffectAssets.FindFruit("Gravity", "Power4", "GravityCrush")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not fullSize or not fullSeconds or fullSeconds <= 0 or not template or not template:IsA("BasePart") then
		return noop
	end
	if not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local root: BasePart = foundRoot
	local size: number, seconds: number = fullSize, fullSeconds

	local ring = template:Clone()
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	local primary = FruitColor.Parse(fields[3] or "")
	if primary then
		ring.Color = primary
	end

	local started = os.clock()
	local function place()
		local charge = math.clamp((os.clock() - started) / seconds, MIN_CHARGE, 1)
		ring.Size = SHAPE * (size * charge)
		ring.CFrame = CFrame.new(root.Position) * UPRIGHT
	end
	place()
	ring.Parent = World.Effects()
	local connection = RunService.RenderStepped:Connect(place)

	return function()
		connection:Disconnect()

		local tweenInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
		ring.Transparency = RELEASE_TRANSPARENCY
		TweenService:Create(ring, tweenInfo, { Transparency = 1 }):Play()
		for _, child in ring:GetChildren() do
			if child:IsA("Texture") then
				TweenService:Create(child, tweenInfo, { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(ring, FADE_TIME)
	end
end
