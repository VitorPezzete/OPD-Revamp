--!strict
--[[
	The puff a character leaves where it vanishes with Shave: a BillboardGui sized in
	studs that bursts outwards and thins out over its short life. The caller destroys it
	(by cleaning the scope) when the flash is over.

		local flash = ShaveFlash(scope, { Duration = 0.175 })
		flash.Adornee = attachment
		flash.Parent = attachment

	Not part of the Components index: required by its own path (Effects.OneShot.Shave).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Props = {
	-- Seconds the burst takes; the flash is expected to be removed after it.
	Duration: number?,
	MaxDistance: number?,
}

-- Game art: the smoke puff of the old effect.
local PUFF = "rbxassetid://79719642659878"
-- Studs.
local SIZE = 8
-- Share of the billboard the puff covers when it appears / when it is gone.
local START_SCALE = 0.55
local END_SCALE = 1
local END_TRANSPARENCY = 0.65

return function(scope: Scope, props: Props): BillboardGui
	local puff: ImageLabel = scope:New("ImageLabel")({
		Name = "Puff",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(START_SCALE, START_SCALE),
		BackgroundTransparency = 1,
		Image = PUFF,
		ImageColor3 = Theme.Colors.PrimaryDark,
		ScaleType = Enum.ScaleType.Fit,
	}) :: any

	local burst = TweenService:Create(
		puff,
		TweenInfo.new(props.Duration or 0.175, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(END_SCALE, END_SCALE), ImageTransparency = END_TRANSPARENCY }
	)
	table.insert(scope, burst)
	burst:Play()

	return scope:New("BillboardGui")({
		Name = "ShaveFlash",
		Size = UDim2.fromScale(SIZE, SIZE),
		AlwaysOnTop = true,
		MaxDistance = props.MaxDistance or 100,
		LightInfluence = 0,
		ResetOnSpawn = false,
		[Fusion.Children] = { puff },
	}) :: any
end
