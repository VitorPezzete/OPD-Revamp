--!strict
--[[
	Status icons shown under the health bar (legacy StatusEffectsGUI, a 400-line chain of
	one BoolValue listener + one `if` per status).

	Status is the replicated character attribute (= server status name). An icon shows
	while the attribute is set. Text may be a function of the attribute value.
	Images are the legacy ones (HealthBar.Frame.Imagery and the ids hardcoded in the script).
]]
export type StatusIcon = {
	Status: string,
	Text: string | (value: any) -> string,
	Image: (string | (value: any) -> string)?,
}

local function asset(id: number): string
	return `rbxassetid://{id}`
end

local Icons: { StatusIcon } = {
	-- Damage over time / debuffs
	{ Status = "MagmaBurn", Text = "Magma is burning you!", Image = asset(5458449558) },
	{ Status = "FlareBurn", Text = "You are on fire!", Image = asset(5458441699) },
	{ Status = "VenomDoT", Text = "Venom seeps into your body!", Image = asset(5458451134) },
	{ Status = "CandyTouched", Text = "You are covered in sticky candy!", Image = asset(5688145965) },
	{ Status = "ChillyPunched", Text = "You have been frozen in ice!", Image = asset(5458447034) },
	{ Status = "AbilitiesDisabled", Text = "Abilities are disabled!", Image = asset(5688146386) },
	{ Status = "GasAirless", Text = "You are choking!", Image = asset(5458442314) },
	{ Status = "SmokeSuffocating", Text = "You are suffocating!" },
	{ Status = "DoughMochiCovered", Text = "You are covered in mochi!" },
	{ Status = "OpeHeartStolen", Text = "Heartless", Image = asset(5458443862) },
	{ Status = "OpeSevered", Text = "You are scattered into pieces!", Image = asset(5458454230) },
	{ Status = "HobbyToy", Text = "You are a toy!", Image = asset(5458444584) },
	{ Status = "HobbyControlled", Text = "Someone is possessing you!", Image = asset(5458451679) },
	{ Status = "LoveStunned", Text = "Turned to stone by love!", Image = asset(5458448204) },
	{ Status = "HollowNegative", Text = "You are depressed!", Image = asset(5458450565) },
	{ Status = "RumbleStun", Text = "Electricity violently shakes you!", Image = asset(5458453686) },
	{ Status = "VampireBitten", Text = "Marked by the vampire's curse!", Image = asset(5644211707) },
	{ Status = "SnowTouched", Text = "Hypothermia!", Image = asset(5458456756) },
	{ Status = "StringInsideCage", Text = "You are trapped inside a cage!" },
	{
		-- One status for both legacy flags (Mored / Returned): its value is the body scale.
		Status = "MoreMored",
		Text = function(value: any): string
			return if type(value) == "number" and value < 1 then "You are tiny!" else "You are giant!"
		end,
		Image = function(value: any): string
			return if type(value) == "number" and value < 1 then asset(5458452760) else asset(5458450052)
		end,
	},

	-- Own states
	{ Status = "Haki", Text = "You are infused with haki!", Image = asset(5458437768) },
	{ Status = "UsingObs", Text = "You sense the world around you!", Image = asset(5458447529) },
	{ Status = "DiamondBody", Text = "Hard diamond covers your body!", Image = asset(5458440874) },
	{ Status = "SmeltBody", Text = "You are coated in molten silver!", Image = asset(5458454931) },
	{ Status = "HotBody", Text = "Your skin incinerates others!", Image = asset(5688146718) },
	{ Status = "HotFlying", Text = "Nose jets propel you!" },
	{ Status = "BarrierBody", Text = "You are covered in barriers!", Image = asset(5458437181) },
	{ Status = "CandyBody", Text = "Candy spikes surround you!", Image = asset(5458438175) },
	{ Status = "Invisible", Text = "You are invisible!", Image = asset(5458439649) },
	-- The legacy icon was stored as "UsingGear2nd" but looked up as "UsingGum2nd": it never showed.
	{ Status = "Gum2nd", Text = "Your rubber body is pushed to its limit!", Image = asset(5458442813) },
	{ Status = "MagmaBody", Text = "You are covered in magma!", Image = asset(5458448667) },
	{ Status = "PhoenixSoaring", Text = "You soar through the air!" },
	{ Status = "PhoenixRevived", Text = "Revived!", Image = asset(5823555324) },
	{ Status = "SnowBody", Text = "You are snow!", Image = asset(5458455595) },
	{ Status = "SnowFlying", Text = "You have wings made of snow!", Image = asset(5458456227) },
	{ Status = "VenomBody", Text = "Venom drips from your body!", Image = asset(5458457279) },
	{ Status = "VenomDemon", Text = "A venomous demon envelopes you!", Image = asset(5458457803) },
	{ Status = "BloodConcentrate", Text = "A strong flow of blood runs through your body!", Image = asset(101017178910451) },
	{ Status = "HollowProjecting", Text = "You are projecting a ghost!", Image = asset(5458452155) },
	{ Status = "VampireBatAttack", Text = "A bat will follow your next attack!" },
	{ Status = "RumbleLightningSlash", Text = "Lightning runs through your body!", Image = asset(5458437768) },
}

return table.freeze(Icons)
