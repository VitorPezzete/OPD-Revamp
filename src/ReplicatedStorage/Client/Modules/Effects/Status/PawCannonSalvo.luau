--!strict
--[[
	Paw fruit - Pad Cannon while its salvo leaves. Owner only, nothing is drawn: the
	client keeps streaming its aim (PawFx.StreamAim) so every paw leaves along the camera
	at that moment - the source asked the client for its mouse before each paw - and plays
	the release clip (LoveBeamRelease at 1.23 speed) once, when the salvo starts.

	Status value: "<fruit slot>|<ability slot>".
]]
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local PawFx = require(script.Parent.Parent.Util.PawFx)

local RELEASE_SPEED = 1.23

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot, abilitySlot = tonumber(fields[1]), tonumber(fields[2])
	if not isLocal or not fruitSlot or not abilitySlot then
		return noop
	end

	PawFx.PlayRelease(character, PawFx.Anims.LoveBeamRelease, RELEASE_SPEED)
	return PawFx.StreamAim(character, fruitSlot, abilitySlot)
end
