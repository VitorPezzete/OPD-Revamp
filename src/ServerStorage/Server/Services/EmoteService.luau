--!strict
--[[
	Emote ownership. Emotes are bought from the EmoteMerchant through ShopService; this
	service owns what a purchase gives (data.Emotes[name] = true).

	Playing an emote needs no server call: the animation runs on the owner's Animator
	and replicates by itself (EmoteController). A client that plays an emote it has not
	bought only cheats a cosmetic it could already play with any local animation, so
	there is deliberately no "play" remote to gate - the legacy game had none either.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local EmoteConfig = require(ReplicatedStorage.Shared.Configs.EmoteConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type PlayerData = PlayerData.PlayerData

local MARK_PREFIX = "CB_Mark"
-- Meditate: every player has it.
local FREE_MARK = 3

local EmoteService = Knit.CreateService({
	Name = "EmoteService",
	Client = {},
})

local DataService
local NotifyService

-- "CB_Mark7" -> 7, for the unlockable emotes that exist.
local function getMarkIndex(emoteName: string): number?
	local index = tonumber(string.match(emoteName, `^{MARK_PREFIX}(%d+)$`))
	if index and EmoteConfig.Marks[index] then
		return index
	end
	return nil
end

function EmoteService:Owns(player: Player, emoteName: string): boolean
	local index = getMarkIndex(emoteName)
	local data = DataService:GetData(player)
	if not index or not data then
		return false
	end
	return index == FREE_MARK or data.Data.Emotes[emoteName] == true
end

-- For rewards outside the shop. False when the name is not an emote or it is already owned.
function EmoteService:Grant(player: Player, emoteName: string): boolean
	local data = DataService:GetData(player)
	if not data or not getMarkIndex(emoteName) or EmoteService:Owns(player, emoteName) then
		return false
	end
	data:Set(`Emotes.{emoteName}`, true)
	return true
end

function EmoteService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")

	Knit.GetService("ShopService"):RegisterGrant("Emote", {
		Check = function(player: Player, _data: PlayerData, item: ShopConfig.Item): (boolean, string?)
			if not getMarkIndex(item.Name) then
				return false, "This emote is unavailable"
			end
			if EmoteService:Owns(player, item.Name) then
				return false, "You already own this emote"
			end
			return true, nil
		end,
		Give = function(player: Player, _data: PlayerData, item: ShopConfig.Item): boolean
			if not EmoteService:Grant(player, item.Name) then
				return false
			end
			NotifyService:Send(player, "Emote unlocked!", "Success", 3)
			return true
		end,
	})
end

return EmoteService
