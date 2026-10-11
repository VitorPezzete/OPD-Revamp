--!strict
--[[
	The health bar over a character's head: a BillboardGui sized in studs, hidden while
	the character is at full health (or has no health yet).

		local plate = Nameplate(scope, {
			Health = health,              -- state or number
			MaxHealth = maxHealth,
			StudsOffset = Vector3.new(0, 1, 0),
		})
		plate.Adornee = head
		plate.Parent = head

	The fill turns from green to yellow to red as the health drops. Not part of the
	Components index: required by its own path (NameplateController).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = {
	Health: UsedAs<number>,
	MaxHealth: UsedAs<number>,
	-- Where the plate floats, from the adornee's centre.
	StudsOffset: Vector3?,
	MaxDistance: number?,
}

-- Studs.
local WIDTH = 3.2
local HEIGHT = 0.15
-- Lifts the bar clear of the engine's name tag.
local RISE = Vector3.new(0, 0.4, 0)

return function(scope: Scope, props: Props): BillboardGui
	local ratio = scope:Computed(function(use): number
		local maximum = use(props.MaxHealth)
		local value = if maximum > 0 then use(props.Health) / maximum else 0
		return if value == value then math.clamp(value, 0, 1) else 0
	end)
	return scope:New("BillboardGui")({
		Name = "Nameplate",
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffset = (props.StudsOffset or Vector3.zero) + RISE,
		MaxDistance = props.MaxDistance or 100,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = scope:Computed(function(use): boolean
			local maximum = use(props.MaxHealth)
			return maximum > 0 and use(props.Health) < maximum
		end),
		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Track",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.HealthLost,
				BackgroundTransparency = Theme.Transparency.Hud,
				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Fill",
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(ratio), 1)
						end),
						BackgroundColor3 = Theme.Colors.Health,
					}),
				},
			}),
		},
	}) :: any
end
