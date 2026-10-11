--!strict
--[[
	String fruit - Bird Cage, while the key is held: a pole of string grows up and down
	from the hand that started the charge and stays where it started.

	Status value: "<x>|<y>|<z>|<full length>|<full thickness>|<haki 0/1>|<fruit colors>|<Right|Left>".
	Template: ReplicatedStorage.Assets.Models.Fruits.String.Power5.StringCageSpot (an
	upright part with a cylinder mesh). Its size goes from (0.1, 2, 3) to
	(full length, full thickness, 5) in 20 s, linearly, as in the legacy game; the cage
	effect (Effects.Status.StringBirdCage) takes over at the release.

	First fruit color, or dark when the charge started with armament haki on.
	Owner only: the charge animation (wind-up clip, then the held clip).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_TIME = 20
local START_SIZE = Vector3.new(0.1, 2, 3)
local FULL_WIDTH = 5
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local x, y, z = tonumber(fields[1]), tonumber(fields[2]), tonumber(fields[3])
	local fullLength = tonumber(fields[4])
	local fullThickness = tonumber(fields[5])
	local left = fields[8] == "Left"

	local pole: BasePart? = nil
	local template = EffectAssets.FindFruit("String", "Power5", "StringCageSpot")
	if x and y and z and fullLength and fullThickness and template and template:IsA("BasePart") then
		local spot = template:Clone()
		for _, descendant in spot:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Size = START_SIZE
		spot.CFrame = spot.CFrame.Rotation + Vector3.new(x, y, z)

		local primary = FruitColor.Parse(fields[7] or "")
		if fields[6] == "1" then
			spot.Color = HAKI_COLOR
		elseif primary then
			spot.Color = primary
		end

		spot.Parent = World.Effects()
		TweenService:Create(spot, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear), {
			Size = Vector3.new(math.max(fullLength, START_SIZE.X), fullThickness, FULL_WIDTH),
		}):Play()
		pole = spot
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local animator = Animations.FindAnimator(character)
	if isLocal and animator then
		local anims = AnimationConfig.FruitAnims
		local windUp = Animations.Get(animator, if left then anims.WaveLeftCharge else anims.WaveRightCharge)
		local held = Animations.Get(animator, if left then anims.WaveLeftCharged else anims.WaveRightCharged)
		table.insert(tracks, windUp)
		table.insert(tracks, held)
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		if pole then
			pole:Destroy()
		end
	end
end
