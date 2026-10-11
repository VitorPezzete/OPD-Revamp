--!strict
--[[
	What the game says about itself. The legacy place kept these in StringValues of
	Workspace.GlobalReference (Version, VersionChangelogs), which no longer exists.

	Version is also what tells servers apart when the developers shut down the servers of
	one version (ServerPolicyService): change it with every release.

	A release is added at the top of RELEASES: its name becomes the version, and the
	changelog lists every release under its own heading, the newest first. The panels that
	show it use rich text, so a line may not hold a bare "<" or "&".
]]
local RELEASES: { { Version: string, Notes: { string } } } = {
	{
		Version = "Revamp 0.0.0b",
		Notes = {
			"Ice Wave freezes NPC enemies as soon as it hits again. It used to freeze them five seconds later, or not at all.",
			"Clicking a kitchen stove cooks every raw fish you carry. Using a fish next to a fire now does the same.",
			'The "Eat a Devil Fruit" challenge no longer completes when you unbind or swap fruits.',
			"Fixed two cases where a character could be left unable to walk after being hit (reported with Quake).",
			"Diamond Body keeps its diamond look with Armament Haki on: only the arms and legs darken.",
			"Tap to Charge now works on touch with the Auto and Custom button layouts, for buttons set to Hold.",
			"New Reset Settings button in Settings. Keybinds, UI Style and your custom button layout are kept.",
			"Touch: the ability buttons and the player list hide while a menu or the emote list is open.",
			"Touch: menus stay on screen at a high UI Scale.",
			"Phones: the player list starts folded.",
			"Touch, Legacy look: the emote list is the new window, which fits the screen and has a close button.",
		},
	},
	{
		Version = "Revamp 0.0.0a",
		Notes = {
			"The game was rebuilt from the ground up. Your data was carried over: levels, Beri, Gems, fruits, items, storages, clothing, emotes, expertise, affinities, challenges, crews and bounty.",
			"New interface. Pick between the Rework and the Legacy look in Settings > UI Style.",
			"New spawn menu and logo.",
			"Legacy look: Shop, Customize, Accessories, Crew, Stats, Expertise and Talents menus redone and centred.",
			"Controller and touch support, with a camera lock (tap) and zoom (hold) on the same button.",
			"Extreme performance mode now really flattens every material.",
			"!time now answers in the chat.",
			"Players in a Raid are allies: they can no longer damage, stun or push each other.",
			"Sword slashes can be targeted again (Gum Rocket can grab one).",
			"??? Strange Compass: easier to reach its mark, same as the Strange Compass.",
			"Strange Compass Shop now tells you why a claim was refused.",
			"Fishing minigame fixed on the Rework look.",
			"Temporarily disabled: Conqueror's Haki, Trading and Quake's Quake Punch.",
			"Player data is now backed up every day.",
			"New anti-exploit checks and staff tools.",
		},
	},
}

local sections: { string } = {}
for _, release in RELEASES do
	table.insert(sections, `<b>{release.Version}</b>\n{table.concat(release.Notes, "\n")}`)
end

return table.freeze({
	-- Bottom-right corner label.
	Version = RELEASES[1].Version,
	-- Text of the spawn screen's changelog panel.
	Changelog = table.concat(sections, "\n\n"),
})
