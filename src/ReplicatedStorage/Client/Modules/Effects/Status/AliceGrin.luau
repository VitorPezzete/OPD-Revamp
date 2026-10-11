--!strict
--[[
	Alice fruit - Cheshire's Grin, on a victim (3 s, until the blast).

	Everyone sees the cat floating over the victim's head: still for 2.5 s, then one turn
	while it fades out over the last second (it outlives the status by half a second, as
	the legacy 3.5 s billboard outlived the blast). A Grin called off early takes the cat
	away at once.
	Template: ReplicatedStorage.Assets.Models.Fruits.Alice.Power4.ChesireCat (BillboardGui
	with an ImageLabel).

	The inverted world the victim sees meanwhile is its own status
	(Effects.Status.AliceInverted), shared with Wonderland.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local CAT_LIFETIME = 3.5
local CAT_FADE_DELAY = 2.5
local CAT_FADE = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function noop() end

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local shownAt = os.clock()
	local cat: BillboardGui? = nil
	local fade: thread? = nil

	local head = character:FindFirstChild("Head")
	local template = EffectAssets.FindFruit("Alice", "Power4", "ChesireCat")
	if head and head:IsA("BasePart") and template and template:IsA("BillboardGui") then
		local clone = template:Clone()
		-- The legacy template carried the server Script that did the fade.
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		clone.Adornee = head
		clone.Enabled = true
		clone.Parent = head
		Debris:AddItem(clone, CAT_LIFETIME)
		cat = clone

		local image = clone:FindFirstChildWhichIsA("ImageLabel")
		if image then
			fade = task.delay(CAT_FADE_DELAY, function()
				fade = nil
				TweenService:Create(image, CAT_FADE, { Rotation = 360, ImageTransparency = 1 }):Play()
			end)
		end
	end

	if not cat then
		return noop
	end
	return function()
		-- Past the fade's start the status simply ran out: the cat finishes on its own.
		if cat and os.clock() - shownAt < CAT_FADE_DELAY then
			if fade then
				task.cancel(fade)
			end
			cat:Destroy()
		end
	end
end
