--!strict
--[[
	Candy fruit - Syrup Hook, on the HOOKED character: the rope to the caster, which is
	also what pulls.

	Status value: "<caster user id>|<pull seconds>|<1 when haki>|<fruit colors>|<stamp>".
	The status lasts the pull plus the 2 s the rope lingers.
	Template: ReplicatedStorage.Assets.Models.Fruits.Candy.Power6.CandyRope (a visible
	RopeConstraint); a plain visible rope without it.

	Rope: a real RopeConstraint between the two root parts, as the legacy server made it.
	Its Length goes from the distance to 1 stud over the pull time (default tween: Quad,
	Out) and it then stays until the status ends (2 s later). Every client builds it; a
	client only simulates its own character, so the hooked player's rope drags it to the
	caster, the caster's own rope drags the caster to the hooked one (a rope pulls on
	both ends, as it did), and for everybody else it is only the picture. Hooked NPCs
	are pulled by a rope of the server's.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local END_LENGTH = 1
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local function getRoot(model: Instance?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local casterId = tonumber(fields[1])
	local pullTime = tonumber(fields[2]) or 0
	local haki = fields[3] == "1"
	local primary = FruitColor.Parse(fields[4] or "")

	local caster = if casterId then Players:GetPlayerByUserId(casterId) else nil
	local casterRoot = getRoot(caster and caster.Character)
	local root = getRoot(character)
	if not casterRoot or not root then
		return function() end
	end
	local fromRoot: BasePart = root
	local toRoot: BasePart = casterRoot

	local created: { Instance } = {}

	local hookedAttachment = Instance.new("Attachment")
	hookedAttachment.Name = "CandyHook"
	hookedAttachment.Parent = fromRoot
	table.insert(created, hookedAttachment)

	local casterAttachment = Instance.new("Attachment")
	casterAttachment.Name = "CandyHook"
	casterAttachment.Parent = toRoot
	table.insert(created, casterAttachment)

	local rope: RopeConstraint
	local template = EffectAssets.FindFruit("Candy", "Power6", "CandyRope")
	if template and template:IsA("RopeConstraint") then
		rope = template:Clone()
	else
		rope = Instance.new("RopeConstraint")
		rope.Thickness = 0.3
	end
	rope.Visible = true
	if haki then
		rope.Color = BrickColor.new(HAKI_COLOR)
	elseif primary then
		rope.Color = BrickColor.new(primary)
	end
	rope.Length = (fromRoot.Position - toRoot.Position).Magnitude
	rope.Attachment0 = hookedAttachment
	rope.Attachment1 = casterAttachment
	rope.Parent = fromRoot
	table.insert(created, rope)

	if pullTime > 0 then
		TweenService:Create(rope, TweenInfo.new(pullTime), { Length = END_LENGTH }):Play()
	end

	return function()
		for _, instance in created do
			instance:Destroy()
		end
	end
end
