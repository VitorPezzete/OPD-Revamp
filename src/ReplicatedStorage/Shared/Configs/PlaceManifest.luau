--!strict
--[[
	What each place of the experience loads (PlaceConfig.Role picks the row).

	Every place runs this same codebase, but a place only gets the systems it exists for:
	a service that is not listed is never required there, so its remotes do not exist, its
	loops do not run and its data is never written. The loaders and the interface ask this
	module and nothing else:

		Main.server   requires PlaceManifest.Modules("Services", Server.Services)
		Main.client   requires PlaceManifest.Modules("Controllers", Client.Controllers)
		UIController  registers a screen only if PlaceManifest.Has("Screens", name)
		MenuNew       shows a tab only if PlaceManifest.Has("MenuTabs", key)

	A role is either ALL (the main game: everything that exists, nothing to maintain) or an
	explicit allowlist. Allowlists on purpose: a service written tomorrow shows up in the
	main game by itself and in no other place until somebody adds its name here.

	Adding a name: the module's Knit.GetService / Knit.GetController lookups must all be
	listed too (KnitInit of everything loaded runs before any KnitStart, and a lookup of a
	module that is not loaded errors). A dependency the place should not have is looked
	up with Shared.Util.Optional instead, which answers nil here.

	Names are checked at start-up (Verify): one that matches no module warns loudly.

	A system that is switched off as a whole (SwitchedOff below) is taken out of every
	role, the main game included, whatever the lists say: its modules stay in the tree and
	are never required. Whatever else looks one of them up does it with Optional.

	This module replicates, so clients can read the server list. That tells them nothing
	new: Knit already publishes one folder per loaded service, and the names are those of
	the main game anyway.
]]
local PlaceConfig = require(script.Parent.PlaceConfig)
local TradeConfig = require(script.Parent.TradeConfig)

export type Kind = "Services" | "Controllers" | "Screens" | "MenuTabs"

export type Manifest = {
	-- Server.Services.<Name>
	Services: { string },
	-- Client.Controllers.<Name>
	Controllers: { string },
	-- Client.UI.Screens.<Name> (and its Legacy twin)
	Screens: { string },
	-- Keys of the side menu's tabs (Screens.MenuNew). A tab that opens a separate screen
	-- needs that screen listed as well.
	MenuTabs: { string },
}

local ALL = "All"

--[[
	The raid place: a party fights waves of marines and bosses (RaidRunService). The whole
	combat stack and what shows it; no merchants, no economy, no world content.
]]
local Raid: Manifest = {
	Services = {
		-- Data and the character.
		"DataService",
		"BackupService", -- wherever profiles load: snapshots, restores, global rollback
		"CharacterService",
		"StatService",
		"AppearanceService", -- builds the look; publishes no request here (no Customize tab)
		"NameplateService",
		"PlayerListService", -- rank / bounty attributes of the player list and the chat
		-- Combat.
		"CombatService",
		"StatusService",
		"EffectService",
		"AttackService",
		"WeaponService",
		"WeaponUnlockService", -- boss drops
		"UtilityService", -- grapples and the other used tools of the loadout
		"AbilityService",
		"FruitService",
		"FruitSlotService",
		"HakiService",
		"ConquerorService",
		"MovementService",
		"HitCounterService",
		"WaterService",
		"RewardService", -- kill rewards; the Vampire fruit feeds on its signal
		"TimeService", -- day / night: the Vampire fruit
		-- Input and settings.
		"InputService",
		"SettingsService",
		"HotkeyService",
		-- Enemies and the raid itself.
		"EnemyService",
		"RaidService", -- RaidRunService reports the result through it
		"RaidRunService",
		-- Messages, staff and developer tools.
		"NotifyService",
		"AnnouncementService",
		"ServerPolicyService",
		"AdminService",
		"DevService",
		"WebhookService", -- AuditLog and the exploit reports; posts only where WebhookConfig allows
	},
	Controllers = {
		"DataController",
		"UIController",
		"InputController",
		"SettingsController",
		"GraphicsController",
		"MusicController",
		"TimeController",
		"NavigationController",
		"ChatController",
		"AnimationController",
		"EffectController",
		"MovementController",
		"DashController",
		"WaterController",
		"CameraLockController",
		"ControlsController", -- the "Custom" control layout; InputController looks it up
		"ToolCycleController", -- next / previous tool on a gamepad
		"CombatController",
		"WeaponController",
		"AbilityController",
		"NameplateController",
		"AdminController",
		"DevController",
	},
	Screens = {
		"Blindness",
		"Announcement",
		"HealthBar",
		"AbilityBar",
		"ChargingMenu", -- legacy interface only
		"DevilFruitIcons",
		"HitCounter",
		"CashUpdate",
		"NewUnlock",
		"AimReticle",
		"MobileContext",
		"ControlsEditor", -- opened from the Settings tab
		"ControllerGui",
		"Core_i7",
		"MouseTip",
		"MenuNew",
		"RaidHud",
		"RaidWaiting",
	},
	MenuTabs = { "Stats", "Talents", "Settings" },
}

--[[
	The AFK place: nobody has a body; AfkWorldService pays into the profile and one screen
	shows it. Staff tools stay (bans and the console are AdminService's).
]]
local Afk: Manifest = {
	Services = {
		"DataService",
		"BackupService", -- this place saves profiles too, and players stay across day changes
		"AfkWorldService",
		"AdminService",
		"DevService",
		"WebhookService", -- AuditLog and the exploit reports; posts only where WebhookConfig allows
	},
	Controllers = {
		"DataController",
		"UIController",
		"AdminController",
		"DevController",
	},
	Screens = { "AfkWorld" },
	MenuTabs = {},
}

--[[
	The development place: a baseplate where systems and abilities are run while they are
	written. The character and combat stack, enemies to hit (spawned from the developer
	menu), and the developer tools; no map, no spawn screen (DevPlaceService gives
	everybody a body), no economy, no world content. A system under development is added
	here by name when it is ready to be tried.
]]
local Dev: Manifest = {
	Services = {
		-- Data (never a live profile here, see DataService) and the character.
		"DataService",
		"BackupService", -- on an in-memory store here, like the profiles
		"CharacterService",
		"DevPlaceService",
		"StatService",
		"AppearanceService",
		"NameplateService",
		"PlayerListService",
		-- Combat.
		"CombatService",
		"StatusService",
		"EffectService",
		"AttackService",
		"WeaponService",
		"WeaponUnlockService",
		"UtilityService",
		"AbilityService",
		"FruitService",
		"FruitSlotService",
		"HakiService",
		"ConquerorService",
		"MovementService",
		"HitCounterService",
		"WaterService",
		"RewardService",
		"TimeService",
		-- Input and settings.
		"InputService",
		"SettingsService",
		"HotkeyService",
		-- Bots.
		"EnemyService",
		-- Messages, staff and developer tools.
		"NotifyService",
		"AnnouncementService",
		"ServerPolicyService",
		"AdminService",
		"DevService",
		"WebhookService", -- AuditLog and the exploit reports; posts only where WebhookConfig allows
	},
	Controllers = {
		"DataController",
		"UIController",
		"InputController",
		"SettingsController",
		"GraphicsController",
		"MusicController",
		"TimeController",
		"NavigationController",
		"ChatController",
		"AnimationController",
		"EffectController",
		"MovementController",
		"DashController",
		"WaterController",
		"CameraLockController",
		"ControlsController",
		"ToolCycleController",
		"ItemDropController",
		"CombatController",
		"WeaponController",
		"AbilityController",
		"NameplateController",
		"AdminController",
		"DevController",
	},
	Screens = {
		"Blindness",
		"Announcement",
		"HealthBar",
		"AbilityBar",
		"ChargingMenu", -- legacy interface only
		"DevilFruitIcons",
		"HitCounter",
		"CashUpdate",
		"NewUnlock",
		"AimReticle",
		"MobileContext",
		"ControlsEditor",
		"ControllerGui",
		"Core_i7",
		"MouseTip",
		"MenuNew",
		"GiverGUI", -- eating a fruit item handed out by the developer menu
		"DropGui",
	},
	MenuTabs = { "Stats", "Talents", "Settings" },
}

local Roles: { [PlaceConfig.Role]: Manifest | "All" } = {
	Main = ALL,
	-- Nothing is designed for the trade place yet: until it gets a list it is the main game.
	Trade = ALL,
	Raid = Raid,
	AFK = Afk,
	Dev = Dev,
}

--[[
	Systems switched off everywhere, by their own flag: { [kind]: { [name]: true } } of
	what no place loads while the flag is off. Flipping the flag back is all it takes to
	return them (to the roles that list them, and to the ones that load everything).
]]
local SwitchedOff: { [string]: { [string]: boolean } } = {
	Services = {},
	Controllers = {},
	Screens = {},
	MenuTabs = {},
}
if not TradeConfig.Enabled then
	SwitchedOff.Services.TradeService = true
	SwitchedOff.Controllers.TradeController = true
	SwitchedOff.Screens.Trade = true
	SwitchedOff.Screens.TradeInvite = true
	SwitchedOff.MenuTabs.Trade = true
end

local current = Roles[PlaceConfig.Role]

-- { [kind]: { [name]: true } } of this place; nil when it loads everything.
local allowed: { [string]: { [string]: boolean } }? = nil
if type(current) == "table" then
	local sets: { [string]: { [string]: boolean } } = {}
	for kind, names in current :: any do
		local set: { [string]: boolean } = {}
		for _, name in names do
			set[name] = true
		end
		sets[kind] = set
	end
	allowed = sets
end

local PlaceManifest = {}

PlaceManifest.Role = PlaceConfig.Role
-- True in a place that loads everything (no allowlist).
PlaceManifest.LoadsAll = allowed == nil

-- Whether this place loads the module / shows the tab of that name.
function PlaceManifest.Has(kind: Kind, name: string): boolean
	if SwitchedOff[kind][name] then
		return false
	end
	if not allowed then
		return true
	end
	local set = allowed[kind]
	return set ~= nil and set[name] == true
end

-- The ModuleScripts directly under `parent` that this place loads.
function PlaceManifest.Modules(kind: Kind, parent: Instance): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("ModuleScript") and PlaceManifest.Has(kind, child.Name) then
			table.insert(modules, child)
		end
	end
	return modules
end

--[[
	Typo guard, called once per kind at start-up with every name that really exists: a
	listed name that matches none of them warns, since that module would silently be
	missing from this place. Returns whether every name was found.
]]
function PlaceManifest.Verify(kind: Kind, existing: { string }): boolean
	if not allowed then
		return true
	end

	local known: { [string]: boolean } = {}
	for _, name in existing do
		known[name] = true
	end

	local complete = true
	for name in allowed[kind] or {} do
		if not known[name] then
			complete = false
			warn(`[PlaceManifest] {PlaceConfig.Role}.{kind} lists "{name}", which does not exist: check the spelling`)
		end
	end
	return complete
end

-- Names of the ModuleScripts directly under the given containers, for Verify.
function PlaceManifest.NamesIn(...: Instance?): { string }
	local names: { string } = {}
	for index = 1, select("#", ...) do
		local parent = (select(index, ...))
		if parent then
			for _, child in parent:GetChildren() do
				if child:IsA("ModuleScript") then
					table.insert(names, child.Name)
				end
			end
		end
	end
	return names
end

return table.freeze(PlaceManifest)
