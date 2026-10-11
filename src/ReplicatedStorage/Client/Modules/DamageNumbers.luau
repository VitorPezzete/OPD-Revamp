--!strict
--[[
	Floating damage numbers, built locally from CombatService.DamageDealt.
	The legacy game created a part + BillboardGui on the server for every hit.
]]
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LIFETIME = 0.9
local RISE = Vector3.new(0, 4, 0)

local TRAIT_COLORS: { [string]: Color3 } = {
	Melee = Color3.fromRGB(255, 255, 255),
	Sword = Color3.fromRGB(200, 220, 255),
	Special = Color3.fromRGB(255, 170, 60),
	Haki = Color3.fromRGB(170, 90, 255),
	Bleed = Color3.fromRGB(255, 70, 70),
}

local DamageNumbers = {}

local random = Random.new()

function DamageNumbers.Show(amount: number, position: Vector3, trait: string)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position + Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0, 1), random:NextNumber(-1, 1))
	anchor.Parent = Workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 1.5)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextColor3 = TRAIT_COLORS[trait] or TRAIT_COLORS.Melee
	label.Text = tostring(math.max(1, math.round(amount)))
	label.Parent = billboard
	billboard.Parent = anchor

	local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { WorldPosition = anchor.WorldPosition + RISE }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, LIFETIME + 0.1)
end

return DamageNumbers
