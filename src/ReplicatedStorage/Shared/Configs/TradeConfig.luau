--!strict
--[[
	Numbers of the player-to-player trade (TradeService). Shared so the trade screen shows
	the same limits the server enforces; the server is the only one that applies them.
]]

local TradeConfig = {}

--[[
	The switch of the whole trade system. Off: PlaceManifest drops TradeService,
	TradeController, the Trade and TradeInvite screens and the menu's Trade tab from every
	place, so none of them is even required: the remotes do not exist (a client firing
	the old ones reaches nothing), no invitation can be sent or shown, and the settings
	lose their "Trade Requests" row. Nothing saved is touched (Settings.Trade_Requests
	stays as each player left it).
]]
TradeConfig.Enabled = false

-- Seconds between "both accepted" and the swap. Any change to either offer, or either
-- player taking the acceptance back, stops the countdown.
TradeConfig.ConfirmSeconds = 5
-- After a change to either offer, Accept is refused for this long: nobody can swap an
-- item and have the other side accept the new offer in the same breath.
TradeConfig.ChangeLockSeconds = 2

-- An invitation left unanswered runs out.
TradeConfig.RequestSeconds = 20
-- Between two invitations sent by the same player.
TradeConfig.RequestCooldown = 5
-- Before inviting again someone who declined.
TradeConfig.DeclineCooldown = 30
-- A trade nobody touches is closed.
TradeConfig.IdleSeconds = 180

-- Accounts younger than this (days) cannot trade: fresh accounts are how currencies and
-- items get funnelled into one. 0 turns the check off.
TradeConfig.MinAccountAgeDays = 3

-- Items each side may put up: carried ones, stored fruits and bound fruits together.
TradeConfig.MaxItems = 8
-- Most of one currency a side may put up in a single trade.
TradeConfig.MaxAmount = 1_000_000_000_000

-- Currencies that can change hands, and where they live in the player data.
TradeConfig.Currencies = table.freeze({
	Beri = "Economy.Beri",
	Gems = "Economy.Gems",
}) :: { [string]: string }
TradeConfig.CurrencyOrder = table.freeze({ "Beri", "Gems" })

-- Carried items that can change hands besides devil fruit items (recognised by the server
-- from its own records, never by name alone).
TradeConfig.Compasses = table.freeze({
	Compass = true,
	["Silver Compass"] = true,
	["Golden Compass"] = true,
}) :: { [string]: boolean }

return table.freeze(TradeConfig)
