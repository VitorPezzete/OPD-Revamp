--!strict
--[[
	Diamond fruit - Diamond Body. While the body is active (DiamondBodyGuard status, set
	by the ability) every hit:
	1. drains its current amount from the body's stamina (even if it is then ignored);
	2. is ignored entirely if it is weaker than the user's defense level, whatever its
	   trait;
	3. is otherwise reduced by 0.35 * defense affinity * (defense level / cap).

	The legacy branch had an "unless haki or special" test on rule 2, but it compared the
	damage *style* ("Weapon" / "Ability") with "Haki" / "Special", which never matched:
	weak haki and special hits bounced off like any other in the shipped game, and they
	do here.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local GUARD_STATUS = "DiamondBodyGuard"

type Guard = {
	Reduction: number,
	Threshold: number,
	Drain: (amount: number) -> (),
}

return {
	Name = "DiamondBody",
	-- After shield (200) and perk resistances (300), as in the legacy order.
	Priority = 400,
	Apply = function(context: CombatTypes.DamageContext)
		local guard = context.Target:GetStatus(GUARD_STATUS) :: Guard?
		if not guard then
			return
		end

		local amount = context.Amount
		-- May shatter the body (clearing the status); this hit is still mitigated.
		guard.Drain(amount)

		if amount < guard.Threshold then
			context.Amount = 0
		else
			context.Amount = amount * (1 - math.clamp(guard.Reduction, 0, 1))
		end
	end,
} :: CombatTypes.DamageModifier
