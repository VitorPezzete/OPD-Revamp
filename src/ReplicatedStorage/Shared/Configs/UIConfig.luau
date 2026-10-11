--!strict
--[[
	Which interface the client mounts.

	"Divine": the interface written for the rework (Client.UI.Screens, built from
	          Client.UI.Components and coloured by Client.UI.Theme). A screen that has no
	          new version yet falls back to its legacy one.
	"Legacy": the interface exported from the old game (Client.UI.Legacy). The screens in
	          Kept (and, on a touch device, in TouchKept) are still the rework's, and a
	          screen the old game never had (the touch ability bar, trading, the raid HUD)
	          falls back to the rework's.

	Both sets register screens under the same names, so nothing else in the game needs
	to know which one is mounted. The player picks one with Settings.UI_Style, whose
	values are the keys of Styles; Style is what is mounted until the profile has loaded.

	Settings.UI_Scale enlarges whichever is mounted: ScaleFor(step) is the multiplier.
]]
export type Style = "Divine" | "Legacy"

local UIConfig = {
	Style = "Divine" :: Style,
	-- Settings.UI_Style -> style.
	Styles = table.freeze({ Rework = "Divine", Legacy = "Legacy" }) :: { [string]: Style },
	-- Screens that are the rework's in every style.
	Kept = table.freeze({ HealthBar = true, Core_i7 = true, HitCounter = true }) :: { [string]: boolean },
	-- The same on a phone or a tablet only. The old emote list was made to be held open
	-- with a key: on a phone its second column and its Close row are off the screen, with
	-- no way to close it by touch. The rework's is a window that is fitted to the screen.
	TouchKept = table.freeze({ Emotes = true }) :: { [string]: boolean },
	-- Screens that stay open when the player's character goes away. Every other screen
	-- that can be closed is closed then: a shop or a window opened before a death must
	-- not be left lying over the spawn menu. These go on without a character: a trade
	-- (closing its screen cancels it), the raid's own screens, invitations still pending,
	-- and what the spawn menu itself opens.
	OutlivesCharacter = table.freeze({
		Trade = true,
		TradeInvite = true,
		RaidHud = true,
		RaidWaiting = true,
		TeleportingRaid = true,
		InviteRaid = true,
		ConfirmationEvent = true,
		AfkWorld = true,
		Tutorial = true,
		Private = true,
	}) :: { [string]: boolean },
	-- Screens only the legacy interface has: the rework shows the same thing elsewhere (the
	-- charge bars are on its ability bar), so they are not a fallback for it.
	LegacyOnly = table.freeze({ ChargingMenu = true }) :: { [string]: boolean },
	-- Drawing scale of each set. The legacy one is reproduced as it was; the rework's is
	-- drawn a little smaller than its design size.
	DrawScale = table.freeze({ Divine = 0.9, Legacy = 1 }) :: { [string]: number },
	-- Settings.UI_Scale: each step enlarges the interface by this much.
	ScaleStep = 0.1,
}

function UIConfig.StyleFor(setting: unknown): Style
	return (type(setting) == "string" and UIConfig.Styles[setting]) or UIConfig.Style
end

function UIConfig.ScaleFor(step: unknown): number
	return 1 + (if type(step) == "number" then math.clamp(step, 0, 10) else 0) * UIConfig.ScaleStep
end

return UIConfig
