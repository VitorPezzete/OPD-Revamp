--!strict
--[[
	The marker some enemy models carry over their head (the red sign of raid enemies). It
	shows where the enemies that are left stand, so it is drawn at any distance and through
	walls, unlike the title under it.

		NameplateMarker(scope, { Image = "rbxassetid://...", StudsOffset = offset })

	Sized in pixels: in the models it is a billboard one stud wide, which at a distance
	shrinks to a dot and, next to the title (pixels), ended up under the text. It hangs from
	the same point as the title and is lifted by the title's height, so the two never overlap
	however far the camera is.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Props = {
	Image: string,
	-- Where the title floats, from the adornee's centre (the same value the title gets).
	StudsOffset: Vector3?,
}

-- Pixels.
local SIZE = 26
-- Height of the title's two lines, which the marker sits on.
local TITLE_HEIGHT = 38
-- UI.Components.NameplateTitle: the title's bottom edge.
local RISE = Vector3.new(0, 0.65, 0)
-- In units of the gui's own size: its bottom edge at TITLE_HEIGHT pixels over RISE.
local LIFTED = Vector2.new(0, 0.5 + TITLE_HEIGHT / SIZE)

return function(scope: Scope, props: Props): BillboardGui
	return scope:New("BillboardGui")({
		Name = "NameplateMarker",
		Size = UDim2.fromOffset(SIZE, SIZE),
		StudsOffset = (props.StudsOffset or Vector3.zero) + RISE,
		SizeOffset = LIFTED,
		MaxDistance = math.huge,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Name = "Icon",
				Image = props.Image,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
			}),
		},
	}) :: any
end
