--!strict
--[[
	Client side of the player-to-player trade (TradeService).

	The server owns the trade: it pushes this player's view of it on every change and nil
	(with a reason) when it is over. This controller keeps the last view, passes the
	player's requests on untouched, and opens / closes the screens:

		TradeInvite   when an invitation arrives, for as long as it is valid
		Trade         when a trade starts; it stays open when the trade ends, back on its
		              list of the server's players with the outcome written above it

	Nothing here decides anything: every method is a request the server may refuse, and
	the snapshot it sends back is the only truth.

		TradeController:GetSnapshot()            TradeController.Changed (snapshot?, reason?)
		TradeController:Request(player)          -> Promise<(ok: boolean, reason: string?)>
		TradeController:Respond(accept)
		TradeController:SetAmount("Beri", 500)   TradeController:AddItem(tool)
		TradeController:AddStored("Storage", 3)  TradeController:AddStored("Bound", 1)
		TradeController:RemoveItem(itemId)       TradeController:SetReady(true)
		TradeController:Cancel()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

-- Where an offered item comes from: carried (a Tool), a fruit storage slot, a Bound slot.
export type Source = "Held" | "Storage" | "Bound"
-- What this player is shown of an offered item (TradeService.ItemView).
export type ItemView = {
	Id: number,
	Name: string,
	Kind: "Fruit" | "Compass",
	Source: Source,
	-- Slot number of a stored / bound fruit.
	Slot: number?,
	-- Fruits only. Scores (carried and stored fruits) are 0-10 per skill: the affinity is
	-- 1 + score / 10. Affinities (bound fruits) are the multipliers themselves, 1.0-2.0.
	Fruit: string?,
	Scores: { [string]: number }?,
	Affinities: { [string]: number }?,
	HasAura: boolean?,
}
export type OfferView = { Amounts: { [string]: number }, Items: { ItemView }, Ready: boolean }
export type Snapshot = {
	Partner: Player,
	Mine: OfferView,
	Theirs: OfferView,
	-- Server time (Workspace:GetServerTimeNow) of the swap while the countdown runs.
	ConfirmAt: number?,
	-- Server time until which Accept is refused (an offer was just changed).
	LockedUntil: number,
}

local TRADE_SCREEN = "Trade"
local INVITE_SCREEN = "TradeInvite"

local TradeController = Knit.CreateController({
	Name = "TradeController",
})

-- Fired with (snapshot: Snapshot?, reason: string?); snapshot is nil when the trade is over.
TradeController.Changed = Signal.new()

local UIController
local TradeService

local snapshot: Snapshot? = nil
local inviteToken = 0

local function closeInvite()
	inviteToken += 1
	UIController:Close(INVITE_SCREEN)
end

local function apply(state: Snapshot?, reason: string?)
	local started = state ~= nil and snapshot == nil
	snapshot = state
	if started then
		closeInvite()
		UIController:Open(TRADE_SCREEN)
	end
	TradeController.Changed:Fire(snapshot, reason)
end

function TradeController:GetSnapshot(): Snapshot?
	return snapshot
end

-- Invites `target`. Resolves with (sent: boolean, reason: string?).
function TradeController:Request(target: Player): any
	return TradeService:Request(target)
end

-- Answers the pending invitation and takes its prompt down.
function TradeController:Respond(accept: boolean)
	closeInvite()
	TradeService.Respond:Fire(accept)
end

function TradeController:SetAmount(currency: string, amount: number)
	TradeService.SetAmount:Fire(currency, amount)
end

function TradeController:AddItem(tool: Tool)
	TradeService.AddItem:Fire(tool)
end

-- Offers the fruit sitting in one of this player's own storage or Bound slots. Only the
-- slot is named: the server reads what is in it.
function TradeController:AddStored(source: "Storage" | "Bound", slot: number)
	TradeService.AddStored:Fire(source, slot)
end

function TradeController:RemoveItem(itemId: number)
	TradeService.RemoveItem:Fire(itemId)
end

function TradeController:SetReady(ready: boolean)
	TradeService.SetReady:Fire(ready)
end

function TradeController:Cancel()
	TradeService.Cancel:Fire()
end

function TradeController:KnitInit()
	UIController = Knit.GetController("UIController")
end

function TradeController:KnitStart()
	TradeService = Knit.GetService("TradeService")

	TradeService.Changed:Connect(function(state: Snapshot?, reason: string?)
		apply(if type(state) == "table" then state else nil, if type(reason) == "string" then reason else nil)
	end)

	TradeService.Invited:Connect(function(from: Player, seconds: number)
		if typeof(from) ~= "Instance" or not from:IsA("Player") then
			return
		end
		-- A newer invitation replaces the one on screen.
		closeInvite()
		local token = inviteToken
		UIController:Open(INVITE_SCREEN, { From = from, Seconds = seconds })
		task.delay(if type(seconds) == "number" then seconds else 0, function()
			if inviteToken == token then
				closeInvite()
			end
		end)
	end)

	TradeService.InviteClosed:Connect(closeInvite)

	-- A trade already running when this controller starts (it should not happen: asked once).
	TradeService:GetState()
		:andThen(function(state: Snapshot?)
			if type(state) == "table" and not snapshot then
				apply(state, nil)
			end
		end)
		:catch(warn)
end

return TradeController
