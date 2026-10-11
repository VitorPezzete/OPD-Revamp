--!strict
--[[
	Player-to-player trade: one window with two states.

	No trade running: every other player of the server, each with an Invite button, the
	answer to the last invitation / the outcome of the last trade as one line, and a note
	of what can change hands. Where the players stand does not matter.

	Trade running: three columns and a footer.
	- "Add to your offer": what this player can still put up, one list per source -
	  Carried (fruit items and compasses in the Backpack or in hand), Storage (fruits of
	  the storage slots) and Bound (fruits of the Bound slots). The two last ones are read
	  from the replicated data, like the Storage screen does; a slot already on the table
	  is not listed.
	- "You" and the partner: the Beri, the Gems and the items put up. Every item says where
	  it comes from ("Carried", "Storage 3", "Bound 1") and, for a fruit, its aura mark and
	  its four affinities, so each side sees exactly what it would get. The player's own
	  column is editable: two amounts, and Remove on each item.
	- Footer: Accept, Cancel and, once both have accepted, the countdown to the swap.

	Everything shown of the trade comes from the server's snapshot (TradeController); a
	click or an amount typed is only a request, and the fields go back to what the
	snapshot says. A column whose offer just changed is outlined for a moment, so a
	last-second swap cannot go unnoticed. Closing the screen, however it happens, cancels
	the trade.

	One Heartbeat runs while the screen is open and only works during a trade: twice a
	second it re-reads the carried items; the server clock is only followed while a
	countdown, a lock or a flash is on screen.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local TradeConfig = require(ReplicatedStorage.Shared.Configs.TradeConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local FruitItemCodec = require(ReplicatedStorage.Shared.Util.FruitItemCodec)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type State<T> = Fusion.StateObject<T>
type Side = "Mine" | "Theirs"
type SlotSource = "Storage" | "Bound"
-- The trade as the server shows it to this player (TradeService.Snapshot).
type ItemView = {
	Id: number,
	Name: string,
	Kind: string,
	Source: string,
	Slot: number?,
	Fruit: string?,
	Scores: { [string]: number }?,
	Affinities: { [string]: number }?,
	HasAura: boolean?,
}
type OfferView = { Amounts: { [string]: number }, Items: { ItemView }, Ready: boolean }
type Snapshot = {
	Partner: Player,
	Mine: OfferView,
	Theirs: OfferView,
	ConfirmAt: number?,
	LockedUntil: number,
}
-- Multiplier (1.0-2.0) per skill.
type Multipliers = { [string]: number }
-- What a row says about an item, wherever the item is listed.
type Row = {
	Name: string,
	Order: number,
	Title: string,
	-- Where the item comes from: "Carried", "Storage 3", "Bound 1".
	Tag: string,
	Aura: boolean,
	-- Fruits; without them the row shows Note instead.
	Multipliers: Multipliers?,
	Note: string?,
}
type Action = {
	Text: string,
	Variant: string,
	Disabled: Theme.UsedAs<boolean>?,
	OnClick: () -> (),
}
-- A fruit of the player's own storage / Bound slots that can still be put up.
type SlotEntry = { Row: Row, Source: SlotSource, Slot: number }

local localPlayer = Players.LocalPlayer

local SKILLS = FruitEconomyConfig.Skills
local STORAGE_SLOTS = FruitEconomyConfig.Storage.SlotCount
local BOUND_SLOTS = FruitEconomyConfig.Bound.SlotCount
local EMPTY = FruitItemCodec.Empty
local FRUIT_ATTRIBUTE = "FruitItem"
local MAX_SCORE = 10

-- The same colours as the affinity chart of the storage.
local SKILL_COLORS: { [string]: Color3 } = {
	Defense = Theme.Colors.Success,
	Melee = Theme.Colors.Danger,
	Sniper = Theme.Colors.Warning,
	Sword = Theme.Colors.Gems,
}
local SKILL_SHORT: { [string]: string } = { Defense = "Def" }
local CURRENCY_COLORS: { [string]: Color3 } = {
	Beri = Theme.Colors.Beri,
	Gems = Theme.Colors.Gems,
}
local REASONS: { [string]: string } = {
	Completed = "Trade completed.",
	Cancelled = "Trade cancelled.",
	PartnerLeft = "Trade cancelled: the other player left.",
	Idle = "Trade cancelled: nobody touched it.",
	Failed = "Trade failed: nothing changed hands.",
}
local SOURCE_TABS = {
	{ Key = "Held", Text = "Carried" },
	{ Key = "Storage", Text = "Storage" },
	{ Key = "Bound", Text = "Bound" },
}
local EMPTY_TEXT: { [string]: string } = {
	Held = "You carry nothing that can be traded.",
	Storage = "No stored fruit left to offer.",
	Bound = "No bound fruit left to offer.",
}

-- Seconds a changed column stays outlined.
local FLASH_SECONDS = 2.5
-- Seconds an "Add" waits for the server before the item is listed as carried again.
local PENDING_SECONDS = 3
local CLOCK_STEP = 0.1
local CARRY_STEP = 0.5

-- Wide and low: the window is shrunk as a whole to fit a phone held sideways
-- (ScreenScale), so the flatter it is the larger everything in it stays.
local WINDOW_SIZE = Vector2.new(1280, 700)
local WINDOW_HEADER = 52
local PADDING = Theme.Space.L
local BODY_SIZE = Vector2.new(WINDOW_SIZE.X - PADDING * 2, WINDOW_SIZE.Y - WINDOW_HEADER - PADDING * 2)
local GAP = Theme.Space.S
local COLUMNS = 3
local COLUMN_GAP = Theme.Space.M
local FOOTER_HEIGHT = 64
local COLUMN_SIZE = Vector2.new(
	(BODY_SIZE.X - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS,
	BODY_SIZE.Y - FOOTER_HEIGHT - Theme.Space.M
)
local COLUMN_PADDING = Theme.Space.M
local COLUMN_INNER_HEIGHT = COLUMN_SIZE.Y - COLUMN_PADDING * 2
local HEADER_HEIGHT = 30
local MARKS_WIDTH = 190
local AMOUNT_HEIGHT = 40
local AMOUNT_LABEL = 56
local AMOUNT_INPUT = 130
local HEADING_HEIGHT = 24
local TAB_HEIGHT = 36
local NOTE_HEIGHT = 44
-- A row: title, tags, detail, one under the other.
local ROW_PADDING = 6
local ROW_TITLE = 22
local ROW_TAGS = 24
local ROW_DETAIL = 20
local ROW_LINE_GAP = 2
local ROW_HEIGHT = ROW_TITLE + ROW_TAGS + ROW_DETAIL + ROW_LINE_GAP * 2 + ROW_PADDING * 2
local ROW_BUTTON = Vector2.new(84, 34)
local BUTTON_HEIGHT = 52
local ACCEPT_WIDTH = 300
local CANCEL_WIDTH = 190
-- Lobby.
local LOBBY_NOTE_HEIGHT = 52
local NOTICE_HEIGHT = 30
local PLAYER_CELL = Vector2.new(400, 52)
local INVITE_WIDTH = 120

-- Heights of the lists: what is left of a column under its fixed parts.
local OFFER_FIXED = HEADER_HEIGHT + AMOUNT_HEIGHT * #TradeConfig.CurrencyOrder + HEADING_HEIGHT
local MINE_LIST_HEIGHT = COLUMN_INNER_HEIGHT - OFFER_FIXED - GAP * (2 + #TradeConfig.CurrencyOrder)
local THEIRS_LIST_HEIGHT = MINE_LIST_HEIGHT - NOTE_HEIGHT - GAP
local PICKER_LIST_HEIGHT = COLUMN_INNER_HEIGHT - HEADER_HEIGHT - TAB_HEIGHT - NOTE_HEIGHT - GAP * 3

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Whole amounts as plain digits, for a text box.
local function digits(amount: number): string
	return if amount > 0 then string.format("%.0f", amount) else ""
end

local function plural(count: number, word: string): string
	return `{Bind.formatNumber(count)} {word}{if count == 1 then "" else "s"}`
end

-- Amounts and item ids of an offer: two offers that read the same are the same offer.
local function signature(offer: OfferView): string
	local parts: { string } = {}
	for _, currency in TradeConfig.CurrencyOrder do
		table.insert(parts, string.format("%.0f", offer.Amounts[currency] or 0))
	end
	for _, item in offer.Items do
		table.insert(parts, tostring(item.Id))
	end
	return table.concat(parts, "|")
end

local function sameList(first: { any }, second: { any }): boolean
	if #first ~= #second then
		return false
	end
	for index, value in first do
		if second[index] ~= value then
			return false
		end
	end
	return true
end

local function countSource(items: { ItemView }, source: string): number
	local count = 0
	for _, item in items do
		if item.Source == source then
			count += 1
		end
	end
	return count
end

-- Unlocked, empty slots of the replicated Storages / Bounds table.
local function countFree(slots: any, slotCount: number, field: string): number
	local free = 0
	for slot = 1, slotCount do
		local record = if type(slots) == "table" then slots[tostring(slot)] else nil
		if type(record) == "table" and record.Unlocked == true and record[field] == EMPTY then
			free += 1
		end
	end
	return free
end

-- The other players of the server, by name. `leaving` is still listed while its
-- PlayerRemoving runs.
local function otherPlayers(leaving: Player?): { Player }
	local found: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and player ~= leaving then
			table.insert(found, player)
		end
	end
	table.sort(found, function(first: Player, second: Player): boolean
		return string.lower(first.Name) < string.lower(second.Name)
	end)
	return found
end

---------------------------------------------------------------------------------------
-- What a row says

-- Items keep scores (0-10): a score stands for 1 + score / 10.
local function fromScores(scores: { [string]: number }): Multipliers
	local multipliers: Multipliers = {}
	for _, skill in SKILLS do
		local score = math.clamp(tonumber(scores[skill]) or 0, 0, MAX_SCORE)
		multipliers[skill] = 1 + score / MAX_SCORE
	end
	return multipliers
end

-- Bound fruits keep the multipliers themselves.
local function fromAffinities(affinities: { [string]: number }): Multipliers
	local multipliers: Multipliers = {}
	for _, skill in SKILLS do
		multipliers[skill] = math.clamp(tonumber(affinities[skill]) or 1, 1, 2)
	end
	return multipliers
end

-- A carried fruit only shows its affinities on its tooltip ("Defense: 1.4 | Melee: ...").
local function fromToolTip(toolTip: string): Multipliers?
	local multipliers: Multipliers = {}
	for skill, value in string.gmatch(toolTip, "(%a+): ([%d%.]+)") do
		multipliers[skill] = math.clamp(tonumber(value) or 1, 1, 2)
	end
	for _, skill in SKILLS do
		if not multipliers[skill] then
			return nil
		end
	end
	return multipliers
end

local function tagOf(source: string, slot: number?): string
	if source == "Storage" or source == "Bound" then
		return if slot then `{source} {Bind.formatNumber(slot)}` else source
	end
	return "Carried"
end

-- An item on the table, as the server describes it.
local function describeItem(item: ItemView): Row
	local multipliers: Multipliers? = nil
	local affinities, scores = item.Affinities, item.Scores
	if type(affinities) == "table" then
		multipliers = fromAffinities(affinities)
	elseif type(scores) == "table" then
		multipliers = fromScores(scores)
	end
	local fruit = item.Fruit
	return {
		Name = `Item{item.Id}`,
		Order = item.Id,
		-- The source is written on its own tag, not in the name.
		Title = if type(fruit) == "string" then `{fruit} Fruit` else item.Name,
		Tag = tagOf(item.Source, item.Slot),
		Aura = item.HasAura == true,
		Multipliers = multipliers,
		Note = if item.Kind == "Fruit" then "Devil Fruit" else "Treasure compass",
	}
end

local function isTradable(tool: Instance): boolean
	return tool:IsA("Tool")
		and (type(tool:GetAttribute(FRUIT_ATTRIBUTE)) == "string" or TradeConfig.Compasses[tool.Name] == true)
end

-- The name the server gives the tool once it is offered.
local function offerName(tool: Tool): string
	local fruit = tool:GetAttribute(FRUIT_ATTRIBUTE)
	return if type(fruit) == "string" then `{fruit} Fruit` else tool.Name
end

local function describeTool(tool: Tool, order: number): Row
	local isFruit = type(tool:GetAttribute(FRUIT_ATTRIBUTE)) == "string"
	return {
		Name = "Tool",
		Order = order,
		Title = offerName(tool),
		Tag = "Carried",
		Aura = false,
		Multipliers = if isFruit then fromToolTip(tool.ToolTip) else nil,
		Note = if not isFruit
			then "Treasure compass"
			elseif tool.ToolTip ~= "" then tool.ToolTip
			else "Devil Fruit",
	}
end

local function describeStored(saved: string, slot: number): Row?
	local item = FruitItemCodec.DecodeItem(saved)
	if not item then
		return nil
	end
	return {
		Name = `Storage{slot}`,
		Order = slot,
		Title = `{item.FruitName} Fruit`,
		Tag = tagOf("Storage", slot),
		Aura = item.HasAura,
		Multipliers = fromScores(item.Scores :: any),
	}
end

local function describeBound(saved: string, slot: number): Row?
	local bound = FruitItemCodec.DecodeBound(saved)
	if not bound then
		return nil
	end
	-- A bound fruit with an aura carries its two colours.
	local primary, secondary = FruitColor.Parse(bound.Color)
	return {
		Name = `Bound{slot}`,
		Order = slot,
		Title = `{bound.FruitName} Fruit`,
		Tag = tagOf("Bound", slot),
		Aura = primary ~= nil and secondary ~= nil,
		Multipliers = fromAffinities(bound.Affinities :: any),
	}
end

---------------------------------------------------------------------------------------
-- Pieces

-- The four affinities of a fruit, each in its colour. Four equal cells whose text
-- shrinks to fit, so the line holds in a narrow column.
local function affinityLine(scope: Scope, multipliers: Multipliers): Instance
	local cells: { any } = {}
	for index, skill in SKILLS do
		cells[index] = UI.Label(scope, {
			Name = skill,
			Text = string.format("%s %.1f", SKILL_SHORT[skill] or skill, multipliers[skill] or 1),
			Variant = "Tiny",
			Color = SKILL_COLORS[skill] or Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Scaled = true,
			LayoutOrder = index,
			Size = UDim2.fromScale(1 / #SKILLS, 1),
		})
	end
	return UI.Stack(scope, {
		Name = "Affinities",
		Direction = "Horizontal",
		Gap = 0,
		Size = UDim2.fromScale(1, 1),
		Children = cells,
	})
end

-- One item of a list: its name, its tags (source, aura), a line of detail, an optional action.
local function itemRow(scope: Scope, row: Row, action: Action?): Instance
	local actionWidth = if action then ROW_BUTTON.X + GAP else 0
	local multipliers = row.Multipliers
	return UI.Panel(scope, {
		Name = row.Name,
		LayoutOrder = row.Order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Color = Theme.Colors.Raised,
		Padding = ROW_PADDING,
		Children = {
			UI.Label(scope, {
				Name = "Title",
				Text = row.Title,
				Variant = "BodyBold",
				TextSize = Theme.TextSize.Small,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, -actionWidth, 0, ROW_TITLE),
			}),
			UI.Stack(scope, {
				Name = "Tags",
				Direction = "Horizontal",
				Gap = Theme.Space.XS,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Position = UDim2.fromOffset(0, ROW_TITLE + ROW_LINE_GAP),
				Size = UDim2.new(1, -actionWidth, 0, ROW_TAGS),
				Children = {
					UI.Badge(scope, {
						Name = "Source",
						Text = row.Tag,
						Color = Theme.Colors.TextMuted,
						Soft = true,
						TextSize = Theme.TextSize.Tiny,
						LayoutOrder = 1,
					}),
					if row.Aura
						then UI.Badge(scope, {
							Name = "Aura",
							Text = "Aura",
							Color = Theme.Colors.Warning,
							Soft = true,
							TextSize = Theme.TextSize.Tiny,
							LayoutOrder = 2,
						})
						else nil,
				} :: { any },
			}),
			scope:New("Frame")({
				Name = "Detail",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, -actionWidth, 0, ROW_DETAIL),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				[Fusion.Children] = if multipliers
					then affinityLine(scope, multipliers)
					else UI.Label(scope, {
						Text = row.Note or "",
						Variant = "Tiny",
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Size = UDim2.fromScale(1, 1),
					}),
			}),
			if action
				then UI.Button(scope, {
					Name = "Action",
					Text = action.Text,
					Variant = action.Variant :: any,
					Disabled = action.Disabled,
					TextSize = Theme.TextSize.Small,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(ROW_BUTTON.X, ROW_BUTTON.Y),
					OnClick = action.OnClick,
				})
				else nil,
		} :: { any },
	})
end

local function heading(scope: Scope, text: Theme.UsedAs<string>, order: number): Instance
	return UI.Label(scope, {
		Name = "Heading",
		Text = text,
		Variant = "Small",
		Color = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
	})
end

-- A short explanation under a list; the text shrinks rather than spill out.
local function note(scope: Scope, text: Theme.UsedAs<string>, color: Theme.UsedAs<Color3>?, order: number): Instance
	return UI.Label(scope, {
		Name = "Note",
		Text = text,
		Variant = "Tiny",
		Color = color or Theme.Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Scaled = true,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, NOTE_HEIGHT),
	})
end

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local TradeController = Knit.GetController("TradeController")

		local balances: { [string]: Fusion.Value<any> } = {}
		for currency, path in TradeConfig.Currencies do
			balances[currency] = Bind.data(scope, path, 0)
		end
		-- The player's own fruits, as the Storage screen reads them.
		local storages = Bind.data(scope, "Storages", {})
		local bounds = Bind.data(scope, "Bounds", {})

		local snapshot: Fusion.Value<Snapshot?> = scope:Value(nil :: Snapshot?)
		-- Server time, followed only while something on screen counts down.
		local now = scope:Value(serverNow())
		local flashUntil = { Mine = scope:Value(0), Theirs = scope:Value(0) }
		-- The line of the idle state: answer to the last invitation, outcome of the last trade.
		local notice = scope:Value("")
		local noticeColor = scope:Value(Theme.Colors.TextMuted)
		local players: Fusion.Value<{ Player }> = scope:Value(otherPlayers())
		local carried: Fusion.Value<{ Tool }> = scope:Value({})
		local requesting = scope:Value(false)
		-- Which list of "Add to your offer" is shown: "Held", "Storage" or "Bound".
		local pickerSource: Fusion.Value<any> = scope:Value("Held")

		local amountTexts: { [string]: Fusion.Value<string> } = {}
		local amountBoxes: { [string]: TextBox } = {}
		for _, currency in TradeConfig.CurrencyOrder do
			amountTexts[currency] = scope:Value("")
		end

		local mounted = true
		table.insert(scope, function()
			mounted = false
			-- Walking away from the table ends the trade, whichever way the screen was closed.
			if TradeController:GetSnapshot() then
				TradeController:Cancel()
			end
		end)

		Bind.connect(scope, Players.PlayerAdded, function()
			players:set(otherPlayers())
		end)
		Bind.connect(scope, Players.PlayerRemoving, function(leaving: Player)
			players:set(otherPlayers(leaving))
		end)

		local trading = scope:Computed(function(use): boolean
			return use(snapshot) ~= nil
		end)
		local idle = scope:Computed(function(use): boolean
			return use(snapshot) == nil
		end)

		local function offerOf(use: Fusion.Use, side: Side): OfferView?
			local state = use(snapshot)
			return if state then (state :: any)[side] else nil
		end

		---------------------------------------------------------------------------------
		-- Carried items. The snapshot does not say which Tool an offered item is, so the
		-- screen remembers the tools it sent: `sent` until the server answers, `offered`
		-- once a carried item of the same name has appeared in the offer (oldest request
		-- first). A tool in either table is not listed as available.

		local sent: { [Tool]: number } = {}
		local sentOrder: { Tool } = {}
		local offered: { [Tool]: number } = {}
		local toolOfItem: { [number]: Tool | boolean } = {}
		local toolOrder: { [Tool]: number } = setmetatable({} :: any, { __mode = "k" })
		local nextToolOrder = 0

		local function refreshCarried()
			local tools: { Tool } = {}
			local function collect(container: Instance?)
				if not container then
					return
				end
				for _, child in container:GetChildren() do
					if isTradable(child) and not sent[child :: Tool] and not offered[child :: Tool] then
						table.insert(tools, child :: Tool)
					end
				end
			end
			collect(LocalCharacter.Get())
			collect(localPlayer:FindFirstChildOfClass("Backpack"))
			for _, tool in tools do
				if not toolOrder[tool] then
					nextToolOrder += 1
					toolOrder[tool] = nextToolOrder
				end
			end
			table.sort(tools, function(first: Tool, second: Tool): boolean
				return toolOrder[first] < toolOrder[second]
			end)
			if not sameList(Fusion.peek(carried), tools) then
				carried:set(tools)
			end
		end

		local function forget(tool: Tool)
			sent[tool] = nil
			local index = table.find(sentOrder, tool)
			if index then
				table.remove(sentOrder, index)
			end
		end

		-- Matches the carried items of the offer with the tools that were sent. An item
		-- that left the offer (removed, dropped, lost on death) frees its tool.
		local function reconcile(items: { ItemView })
			local present: { [number]: boolean } = {}
			for _, item in items do
				present[item.Id] = true
			end
			for id, tool in toolOfItem do
				if not present[id] then
					toolOfItem[id] = nil
					if typeof(tool) == "Instance" then
						offered[tool] = nil
					end
				end
			end
			for _, item in items do
				if item.Source == "Held" and toolOfItem[item.Id] == nil then
					local match: Tool? = nil
					for _, tool in sentOrder do
						if offerName(tool) == item.Name then
							match = tool
							break
						end
					end
					if match then
						forget(match)
						offered[match] = item.Id
						toolOfItem[item.Id] = match
					else
						toolOfItem[item.Id] = false
					end
				end
			end
		end

		-- A request the server never answered (refused): the tool is listed again.
		local function expireSent()
			local limit = os.clock() - PENDING_SECONDS
			for index = #sentOrder, 1, -1 do
				local tool = sentOrder[index]
				if (sent[tool] or 0) < limit then
					forget(tool)
				end
			end
		end

		local function addTool(tool: Tool)
			if not Fusion.peek(snapshot) or sent[tool] or offered[tool] then
				return
			end
			sent[tool] = os.clock()
			table.insert(sentOrder, tool)
			TradeController:AddItem(tool)
			refreshCarried()
		end

		---------------------------------------------------------------------------------
		-- Lists. ForValues keeps a row for as long as its value is the same object, and a
		-- snapshot is a fresh table every time: the entries are cached (by item id, by
		-- slot content) so that a change only rebuilds the rows it is about.

		local itemCaches: { [Side]: { [number]: ItemView } } = { Mine = {}, Theirs = {} }

		local function offeredItems(side: Side): State<{ ItemView }>
			local cache = itemCaches[side]
			return scope:Computed(function(use): { ItemView }
				local offer = offerOf(use, side)
				local items: { ItemView } = {}
				local present: { [number]: boolean } = {}
				if offer then
					for index, item in offer.Items do
						local known = cache[item.Id] or item
						cache[item.Id] = known
						present[item.Id] = true
						items[index] = known
					end
				end
				for id in cache do
					if not present[id] then
						cache[id] = nil
					end
				end
				return items
			end)
		end

		-- The fruits of the player's own slots that are not on the table yet.
		local function slotEntries(
			source: SlotSource,
			slots: State<any>,
			slotCount: number,
			field: string,
			describe: (saved: string, slot: number) -> Row?
		): State<{ SlotEntry }>
			local cache: { [string]: SlotEntry } = {}
			return scope:Computed(function(use): { SlotEntry }
				local taken: { [number]: boolean } = {}
				local mine = offerOf(use, "Mine")
				if mine then
					for _, item in mine.Items do
						if item.Source == source and item.Slot then
							taken[item.Slot] = true
						end
					end
				end

				local all = use(slots)
				local entries: { SlotEntry } = {}
				local kept: { [string]: SlotEntry } = {}
				for slot = 1, slotCount do
					local record = if type(all) == "table" then all[tostring(slot)] else nil
					local saved = if type(record) == "table" and record.Unlocked == true then record[field] else nil
					if type(saved) == "string" and saved ~= EMPTY and not taken[slot] then
						local key = `{slot}|{saved}`
						local entry = cache[key]
						if not entry then
							local row = describe(saved, slot)
							if row then
								entry = { Row = row, Source = source, Slot = slot }
							end
						end
						if entry then
							kept[key] = entry
							table.insert(entries, entry)
						end
					end
				end
				cache = kept
				return entries
			end)
		end

		local storedEntries = slotEntries("Storage", storages, STORAGE_SLOTS, "Item", describeStored)
		local boundEntries = slotEntries("Bound", bounds, BOUND_SLOTS, "Fruit", describeBound)

		-- Forgets everything that belonged to a trade.
		local function reset()
			table.clear(sent)
			table.clear(sentOrder)
			table.clear(offered)
			table.clear(toolOfItem)
			table.clear(itemCaches.Mine)
			table.clear(itemCaches.Theirs)
		end

		---------------------------------------------------------------------------------
		-- Amounts

		local function limitOf(currency: string): number
			local balance = tonumber(Fusion.peek(balances[currency])) or 0
			return math.clamp(math.floor(balance), 0, TradeConfig.MaxAmount)
		end

		-- The fields show what is on the table, except the one being typed in.
		local function syncAmounts(state: Snapshot)
			for _, currency in TradeConfig.CurrencyOrder do
				local box = amountBoxes[currency]
				if not (box and box:IsFocused()) then
					amountTexts[currency]:set(digits(state.Mine.Amounts[currency] or 0))
				end
			end
		end

		local function submitAmount(currency: string)
			local state = Fusion.peek(snapshot)
			if not state then
				return
			end
			local typed = tonumber(Fusion.peek(amountTexts[currency])) or 0
			local amount = math.clamp(math.floor(typed), 0, limitOf(currency))
			amountTexts[currency]:set(digits(amount))
			if amount ~= (state.Mine.Amounts[currency] or 0) then
				TradeController:SetAmount(currency, amount)
			end
		end

		---------------------------------------------------------------------------------
		-- Snapshots

		-- Until when the clock has to be followed: a lock or a flash is on screen.
		local busyUntil = 0
		local following = false

		local function onSnapshot(state: Snapshot?, reason: string?)
			local previous = Fusion.peek(snapshot)
			if not state then
				snapshot:set(nil)
				reset()
				carried:set({})
				if previous then
					local completed = reason == "Completed"
					notice:set(REASONS[reason or ""] or "The trade is over.")
					noticeColor:set(if completed then Theme.Colors.Success else Theme.Colors.Warning)
				end
				return
			end

			local current = serverNow()
			now:set(current)
			if previous then
				if signature(previous.Mine) ~= signature(state.Mine) then
					flashUntil.Mine:set(current + FLASH_SECONDS)
				end
				if signature(previous.Theirs) ~= signature(state.Theirs) then
					flashUntil.Theirs:set(current + FLASH_SECONDS)
				end
			else
				reset()
				flashUntil.Mine:set(0)
				flashUntil.Theirs:set(0)
				notice:set("")
				pickerSource:set("Held")
			end
			busyUntil = math.max(state.LockedUntil, Fusion.peek(flashUntil.Mine), Fusion.peek(flashUntil.Theirs))
			following = true

			snapshot:set(state)
			reconcile(state.Mine.Items)
			syncAmounts(state)
			refreshCarried()
		end

		local changedConnection = TradeController.Changed:Connect(onSnapshot)
		table.insert(scope, function()
			changedConnection:Disconnect()
		end)
		onSnapshot(TradeController:GetSnapshot(), nil)

		local clockElapsed, carryElapsed = 0, 0
		table.insert(
			scope,
			RunService.Heartbeat:Connect(function(delta: number)
				local state = Fusion.peek(snapshot)
				if not state then
					return
				end

				carryElapsed += delta
				if carryElapsed >= CARRY_STEP then
					carryElapsed = 0
					expireSent()
					refreshCarried()
				end
				clockElapsed += delta
				if clockElapsed >= CLOCK_STEP then
					clockElapsed = 0
					local current = serverNow()
					if state.ConfirmAt or following then
						now:set(current)
						-- One last reading past the end, so nothing stays locked or outlined.
						following = current <= busyUntil
					end
				end
			end)
		)

		---------------------------------------------------------------------------------
		-- Derived state

		local partnerName = scope:Computed(function(use): string
			local state = use(snapshot)
			return if state then state.Partner.DisplayName else "Partner"
		end)
		local locked = scope:Computed(function(use): boolean
			local state = use(snapshot)
			return state ~= nil and use(now) < state.LockedUntil
		end)
		local counting = scope:Computed(function(use): boolean
			local state = use(snapshot)
			return state ~= nil and state.ConfirmAt ~= nil
		end)
		local accepted = scope:Computed(function(use): boolean
			local state = use(snapshot)
			return state ~= nil and state.Mine.Ready
		end)
		-- No more room in the player's offer. Only greys the Add buttons: the server counts.
		local full = scope:Computed(function(use): boolean
			local mine = offerOf(use, "Mine")
			return mine ~= nil and #mine.Items >= TradeConfig.MaxItems
		end)
		-- Carried items are on the table: both players have to be alive at the swap.
		local hasCarried = scope:Computed(function(use): boolean
			local state = use(snapshot)
			return state ~= nil
				and countSource(state.Mine.Items, "Held") + countSource(state.Theirs.Items, "Held") > 0
		end)

		-- What this player needs to receive the partner's stored / bound fruits: free
		-- unlocked slots, counting the ones emptied by what this player gives. A reminder
		-- only - the server checks the room at the swap and fails the trade without it.
		local room = scope:Computed(function(use): { Text: string, Short: boolean }
			local state = use(snapshot)
			if not state then
				return { Text = "", Short = false }
			end
			local needs: { string } = {}
			local short = false
			local function check(source: SlotSource, word: string, free: number)
				local incoming = countSource(state.Theirs.Items, source)
				if incoming > 0 then
					table.insert(needs, plural(incoming, `free {word} slot`))
					if free + countSource(state.Mine.Items, source) < incoming then
						short = true
					end
				end
			end
			check("Storage", "storage", countFree(use(storages), STORAGE_SLOTS, "Item"))
			check("Bound", "Bound", countFree(use(bounds), BOUND_SLOTS, "Fruit"))
			if #needs == 0 then
				return { Text = "", Short = false }
			end
			local text = `You need {table.concat(needs, " and ")} to receive this.`
			if short then
				text ..= " You do not have them: the trade would fail."
			end
			return { Text = text, Short = short }
		end)

		---------------------------------------------------------------------------------
		-- Columns

		local function amountRow(side: Side, currency: string, order: number): Instance
			local color = CURRENCY_COLORS[currency] or Theme.Colors.Text
			local amountText = scope:Computed(function(use): string
				local offer = offerOf(use, side)
				return Bind.formatNumber(if offer then offer.Amounts[currency] or 0 else 0)
			end)

			local children: { any } = {
				UI.Label(scope, {
					Name = "Currency",
					Text = currency,
					Variant = "BodyBold",
					Color = color,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(0, AMOUNT_LABEL, 1, 0),
				}),
			}
			if side == "Theirs" then
				table.insert(
					children,
					UI.Label(scope, {
						Name = "Amount",
						Text = amountText,
						Variant = "BodyBold",
						Color = color,
						TextXAlignment = Enum.TextXAlignment.Right,
						Scaled = true,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(1, -(AMOUNT_LABEL + GAP), 1, 0),
					})
				)
			else
				local text = amountTexts[currency]
				local infoX = AMOUNT_LABEL + AMOUNT_INPUT + GAP * 2
				local box = UI.TextInput(scope, {
					Name = "Input",
					Text = text,
					Placeholder = "0",
					Numeric = true,
					MaxLength = #string.format("%.0f", TradeConfig.MaxAmount),
					Position = UDim2.fromOffset(AMOUNT_LABEL + GAP, 0),
					Size = UDim2.fromOffset(AMOUNT_INPUT, AMOUNT_HEIGHT),
					-- Only a convenience: the server checks the balance again.
					OnChange = function(typed: string)
						local limit = limitOf(currency)
						if (tonumber(typed) or 0) > limit then
							text:set(digits(limit))
						end
					end,
				})
				amountBoxes[currency] = box
				-- Enter and clicking elsewhere both send the amount.
				Bind.connect(scope, box.FocusLost, function()
					submitAmount(currency)
				end)
				table.insert(children, box)
				table.insert(
					children,
					UI.Label(scope, {
						Name = "Amount",
						Text = scope:Computed(function(use): string
							return `On the table: {use(amountText)}`
						end),
						Variant = "Small",
						Color = color,
						TextXAlignment = Enum.TextXAlignment.Left,
						Scaled = true,
						Position = UDim2.fromOffset(infoX, 0),
						Size = UDim2.new(1, -infoX, 0.5, 0),
					})
				)
				table.insert(
					children,
					UI.Label(scope, {
						Name = "Balance",
						Text = scope:Computed(function(use): string
							return `You have {Bind.formatNumber(tonumber(use(balances[currency])) or 0)}`
						end),
						Variant = "Tiny",
						TextXAlignment = Enum.TextXAlignment.Left,
						Scaled = true,
						Position = UDim2.new(0, infoX, 0.5, 0),
						Size = UDim2.new(1, -infoX, 0.5, 0),
					})
				)
			end

			return scope:New("Frame")({
				Name = currency,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, AMOUNT_HEIGHT),
				BackgroundTransparency = 1,
				[Fusion.Children] = children,
			})
		end

		-- The frame of a column: a panel holding `parts` one under the other and, for an
		-- offer, the mark of a change - a thick line around it and a tint that blinks.
		local function column(name: string, index: number, parts: { any }, flashing: State<boolean>?): Instance
			return scope:New("Frame")({
				Name = name,
				Position = UDim2.fromOffset((index - 1) * (COLUMN_SIZE.X + COLUMN_GAP), 0),
				Size = UDim2.fromOffset(COLUMN_SIZE.X, COLUMN_SIZE.Y),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					UI.Panel(scope, {
						Size = UDim2.fromScale(1, 1),
						Color = Theme.Colors.Surface,
						Padding = COLUMN_PADDING,
						Children = UI.Stack(scope, {
							Name = "Content",
							Gap = GAP,
							Size = UDim2.fromScale(1, 1),
							Children = parts,
						}),
					}),
					if flashing
						then scope:New("Frame")({
							Name = "Flash",
							Size = UDim2.fromScale(1, 1),
							BackgroundColor3 = Theme.Colors.Warning,
							BackgroundTransparency = scope:Computed(function(use): number
								return if math.floor(use(now) * 4) % 2 == 0 then 0.86 else 0.94
							end),
							BorderSizePixel = 0,
							Active = false,
							ZIndex = 5,
							Visible = flashing,
							[Fusion.Children] = {
								scope:New("UIStroke")({
									Color = Theme.Colors.Warning,
									Thickness = 3,
								}),
							},
						})
						else nil,
				} :: { any },
			})
		end

		local function offerColumn(side: Side, index: number): Instance
			local mine = side == "Mine"
			local flashing = scope:Computed(function(use): boolean
				return use(now) < use(flashUntil[side])
			end)
			local ready = scope:Computed(function(use): boolean
				local offer = offerOf(use, side)
				return offer ~= nil and offer.Ready
			end)

			local parts: { any } = {
				scope:New("Frame")({
					Name = "Header",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
					BackgroundTransparency = 1,
					[Fusion.Children] = {
						UI.Label(scope, {
							Name = "Who",
							Text = if mine then "You" else partnerName,
							Variant = "Heading",
							Color = Theme.Colors.Accent,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Size = UDim2.new(1, -MARKS_WIDTH, 1, 0),
						}),
						UI.Stack(scope, {
							Name = "Marks",
							Direction = "Horizontal",
							Gap = Theme.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(0, MARKS_WIDTH, 1, 0),
							Children = {
								UI.Badge(scope, {
									Name = "Changed",
									Text = "Changed",
									Color = Theme.Colors.Warning,
									Soft = true,
									TextSize = Theme.TextSize.Tiny,
									LayoutOrder = 1,
									Visible = flashing,
								}),
								UI.Badge(scope, {
									Name = "Accepted",
									Text = scope:Computed(function(use): string
										return if use(ready) then "Accepted" else "Pending"
									end),
									Color = scope:Computed(function(use): Color3
										return if use(ready) then Theme.Colors.Success else Theme.Colors.TextDim
									end) :: any,
									Soft = true,
									TextSize = Theme.TextSize.Tiny,
									LayoutOrder = 2,
								}),
							},
						}),
					},
				}),
			}
			for order, currency in TradeConfig.CurrencyOrder do
				table.insert(parts, amountRow(side, currency, 1 + order))
			end
			table.insert(
				parts,
				heading(
					scope,
					scope:Computed(function(use): string
						local offer = offerOf(use, side)
						local count = if offer then #offer.Items else 0
						return `Items offered ({Bind.formatNumber(count)}/{Bind.formatNumber(TradeConfig.MaxItems)})`
					end),
					10
				)
			)
			table.insert(
				parts,
				UI.Scroll(scope, {
					Name = "Offered",
					LayoutOrder = 11,
					Size = UDim2.new(1, 0, 0, if mine then MINE_LIST_HEIGHT else THEIRS_LIST_HEIGHT),
					Gap = Theme.Space.XS,
					Padding = Theme.Space.XS,
					Children = scope:ForValues(offeredItems(side), function(_, rowScope: Scope, item: ItemView): Instance
						return itemRow(
							rowScope,
							describeItem(item),
							if mine
								then {
									Text = "Remove",
									Variant = "Danger",
									OnClick = function()
										TradeController:RemoveItem(item.Id)
									end,
								}
								else nil
						)
					end),
				})
			)
			if not mine then
				table.insert(
					parts,
					note(
						scope,
						scope:Computed(function(use): string
							return use(room).Text
						end),
						scope:Computed(function(use): Color3
							return if use(room).Short then Theme.Colors.Warning else Theme.Colors.TextMuted
						end),
						12
					)
				)
			end

			return column(side, index, parts, flashing)
		end

		---------------------------------------------------------------------------------
		-- "Add to your offer": one list per source, the selected one shown

		local function pickerList(key: string, rows: any, count: State<number>): { any }
			local shown = scope:Computed(function(use): boolean
				return use(pickerSource) == key
			end)
			return {
				UI.Scroll(scope, {
					Name = key,
					Gap = Theme.Space.XS,
					Padding = Theme.Space.XS,
					Visible = shown,
					Children = rows,
				}),
				UI.Label(scope, {
					Name = `{key}Empty`,
					Text = EMPTY_TEXT[key],
					Variant = "Small",
					Wrapped = true,
					Size = UDim2.new(1, -Theme.Space.L * 2, 1, 0),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					ZIndex = 2,
					Visible = scope:Computed(function(use): boolean
						return use(shown) and use(count) == 0
					end),
				}),
			}
		end

		local function slotRows(entries: State<{ SlotEntry }>): any
			return scope:ForValues(entries, function(_, rowScope: Scope, entry: SlotEntry): Instance
				return itemRow(rowScope, entry.Row, {
					Text = "Add",
					Variant = "Primary",
					Disabled = full,
					OnClick = function()
						if Fusion.peek(snapshot) then
							TradeController:AddStored(entry.Source, entry.Slot)
						end
					end,
				})
			end)
		end

		local function countOf(list: State<{ any }>): State<number>
			return scope:Computed(function(use): number
				return #use(list)
			end)
		end

		local pickerColumn = column("Picker", 1, {
			UI.Label(scope, {
				Name = "Title",
				Text = "Add to your offer",
				Variant = "Heading",
				Color = Theme.Colors.Accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			}),
			UI.Tabs(scope, {
				Name = "Sources",
				Tabs = SOURCE_TABS,
				Selected = pickerSource,
				Gap = GAP,
				TabSize = UDim2.new(1 / #SOURCE_TABS, -GAP, 1, 0),
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			}),
			scope:New("Frame")({
				Name = "Lists",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, PICKER_LIST_HEIGHT),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					pickerList(
						"Held",
						scope:ForValues(carried, function(_, rowScope: Scope, tool: Tool): Instance
							return itemRow(rowScope, describeTool(tool, toolOrder[tool] or 0), {
								Text = "Add",
								Variant = "Primary",
								Disabled = full,
								OnClick = function()
									addTool(tool)
								end,
							})
						end),
						countOf(carried)
					),
					pickerList("Storage", slotRows(storedEntries), countOf(storedEntries)),
					pickerList("Bound", slotRows(boundEntries), countOf(boundEntries)),
				} :: { any },
			}),
			-- Where what is given ends up: the receiver needs the room for it.
			note(
				scope,
				scope:Computed(function(use): string
					local source = use(pickerSource)
					local name = use(partnerName)
					if source == "Storage" then
						return `A stored fruit goes into a free unlocked storage slot of {name}.`
					elseif source == "Bound" then
						return `A bound fruit goes into a free unlocked Bound slot of {name}.`
					end
					return `A carried item goes into the backpack of {name}: both of you must be alive at the swap.`
				end),
				nil,
				4
			),
		})

		---------------------------------------------------------------------------------
		-- Footer of a running trade

		local headline = scope:Computed(function(use): string
			local state = use(snapshot)
			if not state then
				return ""
			end
			if state.ConfirmAt then
				local seconds = math.max(0, math.ceil(state.ConfirmAt - use(now)))
				return `Trading in {Bind.formatNumber(seconds)}...`
			end
			local name = use(partnerName)
			if state.Mine.Ready then
				return `You accepted. Waiting for {name}.`
			elseif state.Theirs.Ready then
				return `{name} accepted. Accept to start the countdown.`
			end
			return "Nobody has accepted yet."
		end)
		local reminder = scope:Computed(function(use): string
			if use(counting) then
				return "Any change to either offer, or taking an acceptance back, stops the countdown."
			elseif use(locked) then
				return "An offer just changed: read both sides again before accepting."
			elseif use(hasCarried) then
				return "Carried items only change hands if both of you are alive at the swap; one lost before that leaves the offer."
			end
			return `Both must accept. The swap happens {Bind.formatNumber(TradeConfig.ConfirmSeconds)} seconds later.`
		end)

		local buttonsWidth = ACCEPT_WIDTH + CANCEL_WIDTH + Theme.Space.M
		local footer = scope:New("Frame")({
			Name = "Footer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
			BackgroundTransparency = 1,
			[Fusion.Children] = {
				UI.Label(scope, {
					Name = "Headline",
					Text = headline,
					Variant = "Heading",
					Font = Theme.Fonts.Display,
					Color = scope:Computed(function(use): Color3
						return if use(counting) then Theme.Colors.Warning else Theme.Colors.Text
					end) :: any,
					TextXAlignment = Enum.TextXAlignment.Left,
					Scaled = true,
					Size = UDim2.new(1, -(buttonsWidth + Theme.Space.L), 0, 36),
				}),
				UI.Label(scope, {
					Name = "Reminder",
					Text = reminder,
					Variant = "Small",
					TextXAlignment = Enum.TextXAlignment.Left,
					Scaled = true,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, -(buttonsWidth + Theme.Space.L), 0, FOOTER_HEIGHT - 38),
				}),
				UI.Stack(scope, {
					Name = "Buttons",
					Direction = "Horizontal",
					Gap = Theme.Space.M,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Children = {
						UI.Button(scope, {
							Name = "Accept",
							Text = scope:Computed(function(use): string
								local state = use(snapshot)
								if state and state.Mine.Ready then
									return "Take back acceptance"
								elseif state and use(locked) then
									local seconds = math.max(1, math.ceil(state.LockedUntil - use(now)))
									return `Offer changed ({Bind.formatNumber(seconds)}s)`
								end
								return "Accept"
							end),
							Variant = scope:Computed(function(use): any
								return if use(accepted) then "Secondary" else "Success"
							end),
							-- Taking an acceptance back is always allowed.
							Disabled = scope:Computed(function(use): boolean
								return use(locked) and not use(accepted)
							end),
							Size = UDim2.fromOffset(ACCEPT_WIDTH, BUTTON_HEIGHT),
							LayoutOrder = 1,
							OnClick = function()
								local state = Fusion.peek(snapshot)
								if not state then
									return
								end
								if state.Mine.Ready then
									TradeController:SetReady(false)
								elseif not Fusion.peek(locked) then
									TradeController:SetReady(true)
								end
							end,
						}),
						UI.Button(scope, {
							Name = "Cancel",
							Text = "Cancel trade",
							Variant = "Danger",
							Size = UDim2.fromOffset(CANCEL_WIDTH, BUTTON_HEIGHT),
							LayoutOrder = 2,
							OnClick = function()
								TradeController:Cancel()
							end,
						}),
					},
				}),
			},
		})

		---------------------------------------------------------------------------------
		-- No trade running: who can be invited

		local function invite(player: Player)
			if Fusion.peek(requesting) then
				return
			end
			requesting:set(true)
			local name = player.DisplayName
			TradeController:Request(player)
				:andThen(function(ok: boolean, reason: string?)
					if not mounted then
						return
					end
					if ok then
						notice:set(`Invitation sent to {name}. Waiting for an answer.`)
						noticeColor:set(Theme.Colors.TextMuted)
					else
						-- The server says why (busy, declined, account too new, ...).
						notice:set(if type(reason) == "string" then reason else "The invitation was not sent.")
						noticeColor:set(Theme.Colors.Warning)
					end
				end)
				:catch(function(problem: any)
					warn(problem)
					if mounted then
						notice:set("The invitation was not sent.")
						noticeColor:set(Theme.Colors.Warning)
					end
				end)
				:finally(function()
					if mounted then
						requesting:set(false)
					end
				end)
		end

		local listTop = LOBBY_NOTE_HEIGHT + NOTICE_HEIGHT + HEADING_HEIGHT + GAP * 3
		local lobby = scope:New("Frame")({
			Name = "Lobby",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = idle,
			[Fusion.Children] = {
				UI.Label(scope, {
					Name = "Note",
					Text = "Invite any player of this server. You can trade Beri, Gems, the Devil Fruit items and "
						.. "treasure compasses you carry, and the fruits of your storage and Bound slots. "
						.. "Nothing changes hands until both of you accept.",
					Variant = "Small",
					Wrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Size = UDim2.new(1, 0, 0, LOBBY_NOTE_HEIGHT),
				}),
				UI.Label(scope, {
					Name = "Notice",
					Text = notice,
					Variant = "BodyBold",
					Color = noticeColor :: any,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(0, LOBBY_NOTE_HEIGHT + GAP),
					Size = UDim2.new(1, 0, 0, NOTICE_HEIGHT),
				}),
				UI.Label(scope, {
					Name = "Heading",
					Text = scope:Computed(function(use): string
						return `Players in this server ({Bind.formatNumber(#use(players))})`
					end),
					Variant = "Small",
					Color = Theme.Colors.Accent,
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(0, LOBBY_NOTE_HEIGHT + NOTICE_HEIGHT + GAP * 2),
					Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
				}),
				UI.Scroll(scope, {
					Name = "Players",
					Position = UDim2.fromOffset(0, listTop),
					Size = UDim2.new(1, 0, 1, -listTop),
					CellSize = PLAYER_CELL,
					Children = scope:ForValues(players, function(_, rowScope: Scope, player: Player): Instance
						return UI.Panel(rowScope, {
							Name = player.Name,
							Color = Theme.Colors.Raised,
							Padding = ROW_PADDING,
							Children = {
								UI.Label(rowScope, {
									Name = "Who",
									Text = if player.DisplayName == player.Name
										then player.Name
										else `{player.DisplayName} (@{player.Name})`,
									Variant = "BodyBold",
									TextSize = Theme.TextSize.Small,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextTruncate = Enum.TextTruncate.AtEnd,
									Position = UDim2.fromOffset(Theme.Space.XS, 0),
									Size = UDim2.new(1, -(INVITE_WIDTH + Theme.Space.XS + GAP), 1, 0),
								}),
								UI.Button(rowScope, {
									Name = "Invite",
									Text = "Invite",
									TextSize = Theme.TextSize.Small,
									-- One invitation at a time: the answer of the server comes first.
									Disabled = requesting,
									AnchorPoint = Vector2.new(1, 0.5),
									Position = UDim2.fromScale(1, 0.5),
									Size = UDim2.new(0, INVITE_WIDTH, 1, 0),
									OnClick = function()
										invite(player)
									end,
								}),
							},
						})
					end),
				}),
				UI.Label(scope, {
					Name = "Empty",
					Text = "Nobody else is in this server.",
					Variant = "Muted",
					Position = UDim2.fromOffset(0, listTop),
					Size = UDim2.new(1, 0, 1, -listTop),
					ZIndex = 2,
					Visible = scope:Computed(function(use): boolean
						return #use(players) == 0
					end),
				}),
			},
		})

		return UI.Screen(scope, {
			Name = "Trade",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Trade",
					Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
					Padding = PADDING,
					OnClose = context.Close,
					Children = {
						lobby,
						scope:New("Frame")({
							Name = "Table",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Visible = trading,
							[Fusion.Children] = {
								pickerColumn,
								offerColumn("Mine", 2),
								offerColumn("Theirs", 3),
								footer,
							},
						}),
					},
				}),
			},
		})
	end,
}
