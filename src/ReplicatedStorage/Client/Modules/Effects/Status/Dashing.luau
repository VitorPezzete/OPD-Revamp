--!strict
--[[
	Dash (MovementService): the "Geppo" kick sound on the character, for everyone who
	has it in view. The status lasts as long as the push; the sound is left to finish.

	The push itself and the animation belong to the owner (DashController).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)

local SOUND_LIFETIME = 3

local function noop() end

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local group = (SoundConfig :: any).SFX
	local definition = group and group["To-Organize"] and group["To-Organize"].Geppo
	if not root or not definition then
		return noop
	end

	local sound = Instance.new("Sound")
	sound.Name = "Dash"
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = root
	sound:Play()
	-- The legacy server never removed these: every dash left one more Sound in the root.
	Debris:AddItem(sound, SOUND_LIFETIME)

	return noop
end
