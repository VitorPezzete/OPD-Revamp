--!strict
--[[
	Conqueror's Haki (Haoshoku): every number of the technique, the names of its statuses
	and the colours a player's haki can have.

	Shared: ConquerorService decides everything with it, the client effects draw with the
	same timings and the touch button reads the unlock rule.

	Stages (saved as Haki.ConquerorStage, 0 = locked):
	1 - a burst that brings everyone around to their knees.
	2 - the same burst, stronger, longer, and able to clash with another user's.
	3 - a 250 stud burst, and the press also wraps the user in a coating that strengthens
	    every hit dealt and softens every hit taken, for as long as there is haki to feed it.
]]

export type Stage = {
	-- Seconds between two uses.
	Cooldown: number,
	-- Fraction of the full haki bar a press costs.
	Cost: number,
	-- Reach in studs: Range + RangePerLevel * Haki level.
	Range: number,
	RangePerLevel: number,
	-- Seconds a victim stays down, and the same for a burst the body released by itself.
	Stun: number,
	AutoStun: number,
	-- Seconds the burst keeps catching whoever walks into it.
	Duration: number,
	-- Meets another user's haki instead of ignoring it.
	Clashes: boolean,
	-- The press also toggles the coating.
	Coating: boolean,
}

local ConquerorConfig = {}

--[[
	The switch of the whole technique. Off: ConquerorService refuses every press and never
	lets a burst out by itself, a coating cannot be put on, and the client offers nothing
	(no key, no gamepad button, no touch button, no row in the hotkey lists: see
	InputConfig.IsEnabled). Saved stages and colours are not touched, so turning it back
	on gives everybody what they had.
]]
ConquerorConfig.Enabled = false

ConquerorConfig.MaxStage = 3
-- Data paths (see DataTemplate).
ConquerorConfig.StagePath = "Haki.ConquerorStage"
ConquerorConfig.ColorPath = "Haki.ConquerorColor"
-- Haki level from which the technique (and its touch button) can be used at all.
ConquerorConfig.HakiLevel = 500

ConquerorConfig.Stages = table.freeze({
	table.freeze({
		Cooldown = 180,
		Cost = 0.15,
		Range = 50,
		RangePerLevel = 0.15,
		Stun = 4,
		AutoStun = 2,
		Duration = 10,
		Clashes = false,
		Coating = false,
	}),
	table.freeze({
		Cooldown = 120,
		Cost = 0.25,
		Range = 50,
		RangePerLevel = 0.15,
		-- 8 seconds plus the 5 the second stage adds on top.
		Stun = 13,
		AutoStun = 9,
		Duration = 10,
		Clashes = true,
		Coating = false,
	}),
	table.freeze({
		Cooldown = 120,
		Cost = 0.25,
		Range = 250,
		RangePerLevel = 0,
		Stun = 10,
		AutoStun = 5,
		Duration = 10,
		Clashes = true,
		Coating = true,
	}),
}) :: { Stage }

-- A burst nobody pressed for: the body lets it out when it is about to fall.
ConquerorConfig.Auto = table.freeze({
	Cost = 0.35,
	-- Health dropping from above HealthHigh to between HealthLow and HealthHigh (fractions
	-- of the maximum): one chance in HealthChance.
	HealthHigh = 0.2,
	HealthLow = 0.1,
	HealthChance = 3,
	-- Being stunned: one chance in StunChance.
	StunChance = 10,
})

-- Seconds between two sweeps of a running burst.
ConquerorConfig.SweepInterval = 0.2
-- Seconds the user cannot be hurt after letting the burst out.
ConquerorConfig.GuardSeconds = 1
-- A victim holding at least this stage does not kneel.
ConquerorConfig.ImmuneStage = 2

ConquerorConfig.Clash = table.freeze({
	-- A difference of this many Haki levels is no contest: the weaker one kneels.
	LevelGap = 25,
	-- Seconds both stand locked, unable to act or to be hurt.
	Seconds = 8,
	-- Seconds before either of them can clash again.
	Lockout = 10,
	-- Everyone this close to the middle of it sees the world take its colour.
	LightRange = 250,
})

ConquerorConfig.Coating = table.freeze({
	-- Every DrainInterval seconds it takes DrainFraction of the full bar (at least DrainMinimum).
	DrainInterval = 4,
	DrainFraction = 0.005,
	DrainMinimum = 1,
	-- Damage dealt by the wearer, damage taken by the wearer, and the same while stunned.
	DamageDealt = 1.15,
	DamageTaken = 0.85,
	DamageTakenStunned = 0.925,
})

-- Replicated statuses are attributes of the character: the client effects carry their names.
ConquerorConfig.Status = table.freeze({
	-- Server only: a burst is running.
	Active = "ConquerorActive",
	-- Server only: cannot be hurt (the instant of the burst, the whole of a clash).
	Guard = "ConquerorGuard",
	-- Server only: is in a clash, or just left one.
	ClashLock = "ConquerorClashLock",
	-- Replicated, value = the wearer's colour as a hex string.
	Coating = "ConquerorCoating",
	-- Replicated, value = the stage of the burst that brought the character down.
	Conquered = "Conquered",
})

-- One-shot effect names (Client.Modules.Effects.OneShot).
ConquerorConfig.Effects = table.freeze({
	Burst = "ConquerorBurst",
	Clash = "ConquerorClash",
})

-- What the effects are made of, for both sides to agree on their length.
ConquerorConfig.Visual = table.freeze({
	-- Stages 1 and 2: a shockwave every Interval seconds for Seconds, swelling to Scale.
	Burst = table.freeze({ Seconds = 3.2, Interval = 0.1, Scale = 65 }),
	-- Stage 3.
	GreatBurst = table.freeze({ Seconds = 7.4, Interval = 0.15, Scale = 250 }),
	-- Seconds the flames stay on the user's head (from stage 2).
	FireSeconds = 3.2,
	ClashInterval = 0.05,
	ClashRing = Vector3.new(150, 3, 150),
})

-- A player's colour is drawn from here the first time it is needed, then saved.
ConquerorConfig.Palette = table.freeze({
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(255, 0, 0),
	Color3.fromRGB(0, 0, 255),
	Color3.fromRGB(85, 0, 127),
	Color3.fromRGB(245, 245, 220),
	Color3.fromRGB(0, 200, 80),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(0, 220, 220),
	Color3.fromRGB(255, 20, 147),
	Color3.fromRGB(180, 180, 180),
})

-- A saved colour ("" or anything unreadable gives nil).
function ConquerorConfig.ParseColor(saved: any): Color3?
	if type(saved) ~= "string" or #saved ~= 6 then
		return nil
	end
	local ok, color = pcall(Color3.fromHex, saved)
	return if ok then color else nil
end

return table.freeze(ConquerorConfig)
