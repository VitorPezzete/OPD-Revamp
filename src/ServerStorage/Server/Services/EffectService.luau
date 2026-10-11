--!strict
--[[
	Visual effects never exist on the server. Two channels reach the clients:

	1. One-shot effects (explosions, slashes): EffectService:Play(name, origin, params)
	   sends a small message to the players near the origin; each client builds it.
	2. Lasting states (invisible, trails, auras): CharacterEntity:SetStatus(..., replicate)
	   mirrors an attribute on the character and clients react to it. Attributes also
	   cover players who join or come into range later, which a remote cannot.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)

local EffectService = Knit.CreateService({
	Name = "EffectService",
	Client = {
		-- (effectName, origin, params). Reliable: an unreliable event drops any message
		-- over about 900 bytes and anything lost on the way, which showed as effects
		-- that sometimes never appeared.
		Play = Knit.CreateSignal(),
	},
})

-- Plays a one-shot effect for everyone within range of origin.
function EffectService:Play(effectName: string, origin: Vector3, params: { [string]: any }?, radius: number?)
	local range = radius or AbilityConfig.EffectRadius
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character.PrimaryPart
		if root and (root.Position - origin).Magnitude <= range then
			EffectService.Client.Play:Fire(player, effectName, origin, params)
		end
	end
end

return EffectService
