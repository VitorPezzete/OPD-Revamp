--!strict
--[[
	Devil fruit boxes: the Tools dug up with a compass (TreasureService), handed out by
	admins or rained by a drop party, and what comes out when one is opened.

	A box is an ordinary Tool recognised by its name (FruitBoxConfig.Boxes). Its holder
	opens it by using it; the client only says "open the box I am holding". The server
	then draws everything: the fruit (every fruit of the box's rarity is as likely), its
	four affinities, and whether it carries an aura (1 in 500; always for a strange box).

	The box a compass digs up remembers its finder. The fruit inside counts as found by
	that player whoever opens the box (FruitLogService owner id: the seller only buys a
	fruit from its finder). Boxes of any other origin belong to whoever opens them.

	Legacy problems fixed here:
	- Each box ran its own server script; opening destroyed the box before the fruit was
	  known to exist, and a fruit without a Backpack to go to was simply lost.
	- Rare and ultra rare boxes posted to Discord webhooks from the opening thread: a slow
	  or failing request delayed or broke the opening. The fruit audit log replaces them.
	- Drop party boxes stayed on the ground forever.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local FruitBoxConfig = require(ServerStorage.Server.Configs.FruitBoxConfig)
local WebhookConfig = require(ServerStorage.Server.Configs.WebhookConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)

local ITEM_FOLDER = "Items"
local BURSTS = WebhookConfig.BoxBursts

local FruitBoxService = Knit.CreateService({
	Name = "FruitBoxService",
	Client = {
		-- Client -> server, no arguments: "open the box I am holding".
		Open = Knit.CreateSignal(),
	},
})

local ChallengeService
local CharacterService
local FruitLogService
local FruitService
local NotifyService
local SeasonService
local WebhookService

-- UserId of the player who dug the box up. Boxes of other origins have no entry.
local finders: { [Tool]: number } = {}
local openLimiter = RateLimiter.new(4, 2)
local random = Random.new()
local warned: { [string]: boolean } = {}
-- Boxes of each rarity opened on this server within the last BURSTS.Window seconds.
local recentOpenings: { [string]: number } = {}

local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn(`[FruitBoxService] {message}`)
	end
end

-- Picks an entry of a percent table; the chances need not add up to 100.
local function pick(odds: { FruitBoxConfig.Chance }): string?
	local total = 0
	for _, entry in odds do
		total += entry.Chance
	end
	if total <= 0 then
		return nil
	end

	local roll = random:NextNumber() * total
	local last: string? = nil
	for _, entry in odds do
		if entry.Chance > 0 then
			last = entry.Box
			roll -= entry.Chance
			if roll < 0 then
				return entry.Box
			end
		end
	end
	return last
end

local function rollFruit(rarity: string): string?
	local pool = FruitBoxConfig.Pools[rarity] or {}
	local seasonal: { string } = {}
	for _, entry in FruitBoxConfig.Seasonal do
		if entry.Rarity == rarity and SeasonService:IsActive(entry.Flag) then
			table.insert(seasonal, entry.Fruit)
		end
	end

	local count = #pool + #seasonal
	if count == 0 then
		return nil
	end
	local index = random:NextInteger(1, count)
	return if index <= #pool then pool[index] else seasonal[index - #pool]
end

-- One affinity of a boxed fruit, as the 0-10 score FruitService stores.
local function rollScore(): number
	local odds = FruitBoxConfig.AffinityOdds
	local total = 0
	for _, entry in odds do
		total += entry.Weight
	end

	local roll = random:NextNumber() * total
	local multiplier = 1
	for _, entry in odds do
		roll -= entry.Weight
		if roll < 0 then
			multiplier = entry.Value
			break
		end
	end
	return math.clamp(math.floor((multiplier - 1) * 10 + 0.5), 0, 10)
end

--[[
	What the legacy boxes posted to Discord: an aura fruit coming out of a box, and many
	rare / ultra rare boxes opened on one server within a minute (somebody is feeding
	on duplicated boxes). Only queued here: WebhookService does the posting.
]]
local function reportOpening(
	player: Player,
	boxName: string,
	rarity: string,
	fruitName: string,
	hasAura: boolean,
	id: string?,
	scores: { [string]: number }
)
	if hasAura or WebhookConfig.NotableBoxFruits[fruitName] then
		local found = `**{player.Name}** ({player.UserId}) has opened a **{boxName}** and got a **{fruitName}** fruit`
		local data = `Defense {scores.Defense}, Melee {scores.Melee}, Sniper {scores.Sniper}, Sword {scores.Sword}`
		local aura = if hasAura then " (AURA)" else ""
		WebhookService:Send("FruitBoxAura", `{found}{aura}\n**ID**: {id or "?"}\n**DATA**: {data}`)
	end

	local threshold = BURSTS.Thresholds[rarity]
	if not threshold then
		return
	end
	local count = (recentOpenings[rarity] or 0) + 1
	recentOpenings[rarity] = count
	task.delay(BURSTS.Window, function()
		recentOpenings[rarity] -= 1
	end)
	if count >= threshold then
		local names: { string } = {}
		for _, other in Players:GetPlayers() do
			table.insert(names, other.Name)
		end
		local opened = `**{count}** {rarity} boxes were opened in the last {BURSTS.Window} seconds!`
		WebhookService:Send("FruitBoxBursts", `{opened} Last by **{player.Name}** ({player.UserId}). Players: {table.concat(names, ", ")}`)
	end
end

local function onOpen(player: Player)
	if not openLimiter:Consume(player) then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not entity or entity.Dead or not backpack then
		return
	end

	-- The holder is the one winner: a Tool is in a single character at a time.
	local box = entity.Model:FindFirstChildOfClass("Tool")
	local definition = box and FruitBoxConfig.Boxes[box.Name]
	if not box or not definition then
		return
	end

	local fruitName = rollFruit(definition.Rarity)
	if not fruitName then
		warnOnce(`no fruit of rarity {definition.Rarity}: "{box.Name}" cannot be opened`)
		return
	end

	local hasAura = definition.AlwaysAura or random:NextInteger(1, FruitBoxConfig.AuraRoll) == 1
	local scores = {
		Defense = rollScore(),
		Melee = rollScore(),
		Sniper = rollScore(),
		Sword = rollScore(),
	}
	local fruit = FruitService:CreateItem(fruitName, scores, hasAura)
	if not fruit then
		-- The box is kept: the next attempt draws again.
		warnOnce(`{fruitName} has no item model under Assets.Models.FruitItems`)
		NotifyService:Send(player, "The box is stuck. Try again.", "Error")
		return
	end

	local finderId = finders[box] or player.UserId
	local boxName = box.Name
	finders[box] = nil
	box:Destroy()

	fruit.Parent = backpack
	local id = FruitLogService:Register(fruit, player, finderId)
	reportOpening(player, boxName, definition.Rarity, fruitName, hasAura, id, scores)
	if hasAura then
		ChallengeService:Record(player, "AuraFruitFound")
	end
end

-- Draws a box name from a percent table (nil when every chance is zero).
function FruitBoxService:Pick(odds: { FruitBoxConfig.Chance }): string?
	return pick(odds)
end

function FruitBoxService:IsBox(name: string): boolean
	return FruitBoxConfig.Boxes[name] ~= nil
end

-- A box Tool, not parented yet. `finderId`: the player whose treasure it is, if any.
function FruitBoxService:Create(boxName: string, finderId: number?): Tool?
	if not FruitBoxConfig.Boxes[boxName] then
		return nil
	end

	local box = ToolTemplates.Create(boxName, ITEM_FOLDER)
	if finderId then
		finders[box] = finderId
		box.Destroying:Once(function()
			finders[box] = nil
		end)
	end
	return box
end

-- Puts a box in the player's backpack.
function FruitBoxService:Give(player: Player, boxName: string, finderId: number?): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local box = if backpack then FruitBoxService:Create(boxName, finderId) else nil
	if box then
		box.Parent = backpack
	end
	return box
end

-- Rains boxes around a point (owner command). Returns how many were dropped.
function FruitBoxService:DropParty(origin: Vector3): number
	local party = FruitBoxConfig.DropParty
	local dropped: { Tool } = {}

	for _ = 1, party.Count do
		local boxName = pick(party.Odds)
		local box = boxName and FruitBoxService:Create(boxName)
		local handle = box and box:FindFirstChild("Handle")
		if box and handle and handle:IsA("BasePart") then
			handle.CanCollide = true
			handle.Position = origin
				+ Vector3.new(
					random:NextInteger(-party.Spread, party.Spread),
					random:NextInteger(party.MinHeight, party.MaxHeight),
					random:NextInteger(-party.Spread, party.Spread)
				)
			box.Parent = World.Drops()
			table.insert(dropped, box)
		elseif box then
			-- Without a Handle a Tool cannot be picked up from the ground.
			warnOnce(`"{box.Name}" has no Handle: it cannot be dropped in the world`)
			box:Destroy()
		end
	end

	-- One timer for the whole party; boxes that were picked up have left the ground.
	if #dropped > 0 then
		task.delay(party.Lifetime, function()
			for _, box in dropped do
				if World.IsOnGround(box) then
					box:Destroy()
				end
			end
		end)
	end
	return #dropped
end

function FruitBoxService:KnitInit()
	ChallengeService = Knit.GetService("ChallengeService")
	CharacterService = Knit.GetService("CharacterService")
	FruitLogService = Knit.GetService("FruitLogService")
	FruitService = Knit.GetService("FruitService")
	NotifyService = Knit.GetService("NotifyService")
	SeasonService = Knit.GetService("SeasonService")
	WebhookService = Knit.GetService("WebhookService")
end

function FruitBoxService:KnitStart()
	FruitBoxService.Client.Open:Connect(onOpen)

	Players.PlayerRemoving:Connect(function(player: Player)
		openLimiter:Forget(player)
	end)
end

return FruitBoxService
