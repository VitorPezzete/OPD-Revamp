--!strict
--[[
	Feeds the combo counter of the HUD: every hit a player lands is sent to that player
	alone, and only if they turned Settings.Hit_Counter on. Nothing is read from clients.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local HitCounterService = Knit.CreateService({
	Name = "HitCounterService",
	Client = {
		-- (damage) to the attacker. Cosmetic, so a dropped packet is acceptable.
		Hit = Knit.CreateUnreliableSignal(),
	},
})

function HitCounterService:KnitStart()
	local CombatService = Knit.GetService("CombatService")

	-- `amount`: the real damage of the hit, not capped by the health the target had left.
	CombatService.Damaged:Connect(function(context: CombatTypes.DamageContext, dealt: number, amount: number)
		local attacker = context.Attacker
		local data = context.AttackerData
		if dealt <= 0 or not attacker or not attacker.Player or not data then
			return
		end
		if data.Data.Settings.Hit_Counter ~= true then
			return
		end
		HitCounterService.Client.Hit:Fire(attacker.Player, amount)
	end)
end

return HitCounterService
