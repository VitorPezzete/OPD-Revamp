--!strict
--[[
	Owns the interface.

	Two sets of screens exist under the same names:
	Client.UI.Screens.<Name>, the interface of the rework, built from UI.Components, and
	Client.UI.Legacy.Screens.<Name>, the one exported from the old game, which drives a
	generated layout. The player picks one (Settings.UI_Style, see UIConfig) and may change
	it while playing: every screen is closed, the other set is registered and the
	persistent screens are mounted again (StyleChanged fires once that is done). A screen
	missing from the chosen set falls back to the other one, and the screens of
	UIConfig.Kept are the rework's in both.

	A screen module must therefore do nothing when it is required: whatever it connects or
	builds belongs to Mount and to the scope Mount is given.

	Screens are discovered automatically:

		return {
			Layout = "Shop2",                 -- generated layout to build (UI.Layouts.<Layout>);
			                                  -- omit to build the whole tree in Mount
			Persistent = false,               -- true: mounted at start and never closed (HUD parts)
			Merchants = { "SwordMerchant" },  -- Workspace.Map.Merchants models that open it on click
			Mount = function(scope, gui, context) end,
		}

	Mount receives a Fusion scope that is cleaned up when the screen closes, the built
	layout (nil without Layout) and a context: { Args, Open, Close, Toggle, IsOpen }.
	Without a Layout, Mount returns the ScreenGui it built.

		UIController:Open("Storage", args)   UIController:Close("Storage")
		UIController:Toggle("Menu")          UIController:IsOpen("Menu")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local UIConfig = require(ReplicatedStorage.Shared.Configs.UIConfig)
local Hotbar = require(ReplicatedStorage.Client.UI.Util.Hotbar)
local Interface = require(ReplicatedStorage.Client.UI.Util.Interface)
local LegacyStyle = require(ReplicatedStorage.Client.UI.Legacy.Style)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

type Scope = Fusion.Scope<typeof(Fusion)>

export type HudState = {
	Health: Fusion.Value<number>,
	MaxHealth: Fusion.Value<number>,
	Shield: Fusion.Value<number>,
	HakiBar: Fusion.Value<number>,
	HakiMax: Fusion.Value<number>,
	Beri: Fusion.Value<number>,
	Spawned: Fusion.Value<boolean>,
}

export type ScreenContext = {
	Name: string,
	Args: any,
	Open: (name: string, args: any?) -> (),
	Close: (name: string?) -> (),
	Toggle: (name: string, args: any?) -> (),
	IsOpen: (name: string) -> boolean,
}

export type Screen = {
	Layout: string?,
	Persistent: boolean?,
	Merchants: { string }?,
	-- A window that reaches the bottom of the screen: on a phone the engine's tool bar is
	-- taken away while it is open (UI.Util.Hotbar). Merchant screens always are.
	HidesHotbar: boolean?,
	-- The style the screen is drawn in, when it is not the one of the set it was loaded
	-- from (a screen both interfaces share).
	Style: UIConfig.Style?,
	Mount: (scope: Scope, gui: any, context: ScreenContext) -> any,
}

local UIController = Knit.CreateController({
	Name = "UIController",
})

-- Fired with (screenName, isOpen).
UIController.ScreenChanged = Signal.new()
-- Fired with (style) after the other interface has been mounted.
UIController.StyleChanged = Signal.new()

local DataController

local localPlayer = Players.LocalPlayer
local scope = Fusion.scoped(Fusion)
local uiFolder = ReplicatedStorage.Client.UI
local legacyFolder = uiFolder.Legacy
local layoutsFolder = legacyFolder.Layouts
local screens: { [string]: Screen } = {}
-- The set each registered screen came from: it is drawn at that set's scale.
local screenStyles: { [string]: UIConfig.Style } = {}
-- Workspace.Map.Merchants model name -> the screen it opens, for the mounted set.
local merchantScreens: { [string]: string } = {}
local boundMerchants: { [Instance]: boolean } = {}
-- Seconds the first mount waits for the profile, which says which interface to mount.
local STYLE_WAIT_SECONDS = 8
local openScreens: { [string]: { Scope: any, Instance: Instance? } } = {}

local state: HudState = {
	Health = scope:Value(0),
	MaxHealth = scope:Value(0),
	Shield = scope:Value(0),
	HakiBar = scope:Value(0),
	HakiMax = scope:Value(0),
	Beri = scope:Value(0),
	Spawned = scope:Value(false),
}

-- Character attribute -> HUD state object.
local ATTRIBUTES: { [string]: Fusion.Value<any> } = {
	Health = state.Health,
	MaxHealth = state.MaxHealth,
	Shield = state.Shield,
	HakiBar = state.HakiBar,
	HakiMax = state.HakiMax,
	Spawned = state.Spawned,
}

local characterConnections: { RBXScriptConnection } = {}

-- The spawn screen, and the PlayerGui attribute that stands in for it where the place
-- has none. Both names are repeated in loaders/Loading.client.luau, which cannot require.
local SPAWN_SCREEN = "Load"
local READY_ATTRIBUTE = "InterfaceReady"

local function unbindCharacter()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	-- No character (spawn screen, death): the HUD reads zero / not spawned.
	for attribute, value in ATTRIBUTES do
		value:set(if attribute == "Spawned" then false else 0)
	end
end

local function bindCharacter(character: Model)
	unbindCharacter()
	-- The hotbar belongs to a character: with none (spawn screen, death) it stays hidden.
	-- Through UI.Util.Hotbar, which also hides it under the menu's windows on a phone: the
	-- Backpack CoreGui is switched nowhere else.
	Hotbar.setCharacter(true)
	for attribute, value in ATTRIBUTES do
		local default = if attribute == "Spawned" then false else 0
		local function update()
			local current = character:GetAttribute(attribute)
			value:set(if current == nil then default else current)
		end
		table.insert(characterConnections, character:GetAttributeChangedSignal(attribute):Connect(update))
		update()
	end
end

function UIController:GetScope()
	return scope
end

-- HUD state objects (health, haki, ...), for screens that display them.
function UIController:GetHudState(): HudState
	return state
end

-- "Divine" or "Legacy": for the few things outside screens that draw interface (nameplates).
function UIController:GetStyle(): UIConfig.Style
	return Interface.getStyle()
end

-- Builds a generated legacy layout without mounting it (templates, billboards).
function UIController:BuildLayout(layoutScope: Scope, name: string): Instance?
	local module = layoutsFolder:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local built = (require :: any)(module)(layoutScope)
	if typeof(built) == "Instance" then
		-- The old game's panels with text that can be read (UI.Legacy.Style).
		LegacyStyle.apply(built)
	end
	return built
end

function UIController:IsOpen(name: string): boolean
	return openScreens[name] ~= nil
end

-- The gui an open screen mounted, nil while it is closed.
function UIController:GetInstance(name: string): Instance?
	local entry = openScreens[name]
	return entry and entry.Instance
end

function UIController:Open(name: string, args: any?)
	local screen = screens[name]
	if not screen or openScreens[name] then
		return
	end

	local screenScope = Fusion.scoped(Fusion)
	local entry = { Scope = screenScope, Instance = nil :: Instance? }
	openScreens[name] = entry

	local context: ScreenContext = {
		Name = name,
		Args = args,
		Open = function(other: string, otherArgs: any?)
			UIController:Open(other, otherArgs)
		end,
		Close = function(other: string?)
			UIController:Close(other or name)
		end,
		Toggle = function(other: string, otherArgs: any?)
			UIController:Toggle(other, otherArgs)
		end,
		IsOpen = function(other: string): boolean
			return UIController:IsOpen(other)
		end,
	}

	local ok, problem = pcall(function()
		local gui: any = nil
		if screen.Layout then
			gui = UIController:BuildLayout(screenScope, screen.Layout)
			if not gui then
				error(`layout "{screen.Layout}" not found`)
			end
		end

		local built = screen.Mount(screenScope, gui, context)
		gui = gui or built
		if typeof(gui) == "Instance" then
			if gui:IsA("ScreenGui") then
				gui.ResetOnSpawn = false
				gui.Enabled = true
				-- Authored for 1920x1080: follow the real resolution and aspect ratio.
				ScreenScale.apply(screenScope, gui, screen.Style or screenStyles[name])
			end
			if gui:IsA("LayerCollector") and gui.Parent == nil then
				gui.Parent = localPlayer:WaitForChild("PlayerGui")
			end
			entry.Instance = gui
		end
	end)

	if not ok then
		warn(`[UI] screen "{name}" failed to mount: {problem}`)
		openScreens[name] = nil
		Fusion.doCleanup(screenScope)
		return
	end
	-- Released with the screen's scope, however the screen is closed.
	-- Never for a screen that is always mounted: the tool bar would be gone for good.
	if
		ScreenScale.Touch
		and not screen.Persistent
		and (screen.HidesHotbar or (screen.Merchants ~= nil and #screen.Merchants > 0))
	then
		table.insert(screenScope, Hotbar.hide())
	end
	UIController.ScreenChanged:Fire(name, true)
end

function UIController:Close(name: string)
	local screen = screens[name]
	local entry = openScreens[name]
	if not entry or (screen and screen.Persistent) then
		return
	end
	openScreens[name] = nil
	Fusion.doCleanup(entry.Scope)
	UIController.ScreenChanged:Fire(name, false)
end

function UIController:Toggle(name: string, args: any?)
	if openScreens[name] then
		UIController:Close(name)
	else
		UIController:Open(name, args)
	end
end

-- Bound once per merchant: the screen it opens is looked up when it is used, so the
-- same binding serves whichever interface is mounted.
local function bindMerchant(merchant: Instance)
	if boundMerchants[merchant] then
		return
	end
	boundMerchants[merchant] = true
	local function open()
		local screenName = merchantScreens[merchant.Name]
		if screenName then
			UIController:Open(screenName, { Merchant = merchant })
		end
	end
	local function bind(descendant: Instance)
		if descendant:IsA("ClickDetector") then
			descendant.MouseClick:Connect(open)
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Triggered:Connect(open)
		end
	end
	-- Its parts can replicate after the model; the connections die with it.
	merchant.DescendantAdded:Connect(bind)
	merchant.Destroying:Connect(function()
		boundMerchants[merchant] = nil
	end)
	for _, descendant in merchant:GetDescendants() do
		bind(descendant)
	end
end

local function loadScreensFrom(
	folder: Instance?,
	style: UIConfig.Style,
	only: { [string]: boolean }?,
	except: { [string]: boolean }?
)
	if not folder then
		return
	end
	for _, module in folder:GetChildren() do
		-- Already provided by the set loaded before.
		if not module:IsA("ModuleScript") or screens[module.Name] or (only and not only[module.Name]) then
			continue
		end
		if except and except[module.Name] then
			continue
		end
		-- Not a screen of this place (PlaceManifest): it does not exist here.
		if not PlaceManifest.Has("Screens", module.Name) then
			continue
		end
		local ok, screen = pcall(require, module)
		if ok and type(screen) == "table" and type(screen.Mount) == "function" then
			screens[module.Name] = screen
			screenStyles[module.Name] = style
		else
			warn(`[UI] screen "{module.Name}" failed to load: {screen}`)
		end
	end
end

-- The chosen set first; the other one only fills in the screens it does not have.
local function loadScreens()
	table.clear(screens)
	table.clear(screenStyles)
	table.clear(merchantScreens)

	local new, legacy = uiFolder:FindFirstChild("Screens"), legacyFolder:FindFirstChild("Screens")
	if Interface.getStyle() == "Legacy" then
		loadScreensFrom(new, "Divine", UIConfig.Kept)
		if ScreenScale.Touch then
			loadScreensFrom(new, "Divine", UIConfig.TouchKept)
		end
		loadScreensFrom(legacy, "Legacy")
		loadScreensFrom(new, "Legacy")
	else
		loadScreensFrom(new, "Divine")
		loadScreensFrom(legacy, "Divine", nil, UIConfig.LegacyOnly)
	end
	for name, screen in screens do
		for _, merchantName in screen.Merchants or {} do
			merchantScreens[merchantName] = name
		end
	end
end

local function openPersistent()
	for name, screen in screens do
		if screen.Persistent then
			-- Deferred so every controller has started before a screen asks for one.
			task.defer(UIController.Open, UIController, name)
		end
	end
end

local function readScale()
	Interface.UserScale:set(UIConfig.ScaleFor(DataController:Get("Settings.UI_Scale")))
end

--[[
	Mounts the other interface: every screen is closed (the persistent ones too), the
	set is registered again and the persistent screens come back. Windows that were open
	stay closed.
]]
local function setStyle(style: UIConfig.Style)
	if style == Interface.getStyle() then
		return
	end
	for name, entry in table.clone(openScreens) do
		openScreens[name] = nil
		Fusion.doCleanup(entry.Scope)
		UIController.ScreenChanged:Fire(name, false)
	end
	Interface.Style:set(style)
	loadScreens()
	openPersistent()
	task.defer(function()
		UIController.StyleChanged:Fire(style)
	end)
end

function UIController:KnitInit()
	DataController = Knit.GetController("DataController")
	loadScreens()
	PlaceManifest.Verify(
		"Screens",
		PlaceManifest.NamesIn(uiFolder:FindFirstChild("Screens"), legacyFolder:FindFirstChild("Screens"))
	)
end

function UIController:KnitStart()
	DataController:Observe("Economy.Beri", function(beri: number?)
		state.Beri:set(beri or 0)
	end)

	localPlayer.CharacterAdded:Connect(bindCharacter)
	localPlayer.CharacterRemoving:Connect(function()
		unbindCharacter()
		Hotbar.setCharacter(false)
		-- Whatever was open belongs to the character that is going (UIConfig.OutlivesCharacter).
		local names = {}
		for name in openScreens do
			local screen = screens[name]
			if not (screen and screen.Persistent) and not UIConfig.OutlivesCharacter[name] then
				table.insert(names, name)
			end
		end
		for _, name in names do
			UIController:Close(name)
		end
	end)
	if localPlayer.Character then
		bindCharacter(localPlayer.Character)
	else
		Hotbar.setCharacter(false)
	end

	-- Every merchant is bound: the ones no screen answers for open nothing.
	task.spawn(function()
		-- The folder can replicate after the client has started.
		local merchants = World.WaitMerchants(60)
		if not merchants then
			return
		end
		-- Some merchants only stand in the folder while they are around (the Haki master).
		merchants.ChildAdded:Connect(bindMerchant)
		for _, child in merchants:GetChildren() do
			bindMerchant(child)
		end
	end)

	-- The profile says which interface the player chose: wait for it (it is on its way
	-- while the loading screen is still up) rather than mount one and swap it at once.
	local waited = 0
	while not DataController:IsReady() and waited < STYLE_WAIT_SECONDS do
		waited += task.wait(0.1)
	end
	if DataController:IsReady() then
		readScale()
		local style = UIConfig.StyleFor(DataController:Get("Settings.UI_Style"))
		if style ~= Interface.getStyle() then
			Interface.Style:set(style)
			loadScreens()
		end
	end
	openPersistent()
	DataController:Observe("Settings.UI_Scale", readScale)
	DataController:Observe("Settings.UI_Style", function(value: any)
		setStyle(UIConfig.StyleFor(value))
	end)

	-- The loading screen (ReplicatedFirst.Loading) leaves when the spawn screen is up. A
	-- place without one tells it so here, once its own persistent screens have been
	-- opened (deferred after their Opens above, so it runs behind them).
	if not screens[SPAWN_SCREEN] then
		task.defer(function()
			localPlayer:WaitForChild("PlayerGui"):SetAttribute(READY_ATTRIBUTE, true)
		end)
	end
end

return UIController
