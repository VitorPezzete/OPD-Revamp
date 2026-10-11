--!strict
--[[
	Talents > Expertise: the level in its blue box, the exp bar, and the honeycomb of
	perks around the hexagon that counts the points left (and respecs them).

		Expertise(scope, { Visible = shown, Position = ..., Size = ... }, menu): Instance

	Built by the Inventory part, which owns the Talents sub-tabs (and builds no page where
	the place does not load ExpertiseService).

	A perk sends its name (ExpertiseService.Invest), the middle hexagon a bare request
	(Respec); the server owns points, limits and the respec cost. Each perk's coloured
	copy is revealed from the bottom as points go in. Hovering (or selecting, on a
	gamepad) a perk shows its tooltip, the middle hexagon the points one.

	The perks keep the rows the old menu drew them in; the rows are now a true honeycomb.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = Kit.Layout & {
	-- The page's own visibility (its sub-tab is the open one).
	Visible: Fusion.UsedAs<boolean>,
}

local peek = Fusion.peek

local RESPEC = "Respec"

local HEXAGON = "rbxassetid://8530145081"
local POINTS_HEXAGON = "rbxassetid://2204238988"
local POINTS_COLOR = Color3.fromRGB(102, 130, 255)
local NO_POINTS_COLOR = Color3.fromRGB(143, 143, 143)
local LEVEL_COLOR = Color3.fromRGB(121, 164, 255)
local EXP_COLOR = Color3.fromRGB(64, 255, 64)
local WHITE = Color3.new(1, 1, 1)

local TITLE_HEIGHT = 44
local LEVEL_SIZE = Vector2.new(380, 44)
local BAR_HEIGHT = 30
-- A hexagon, the step from one to the next in a row, and from a row to the next.
local CELL = 108
local STEP_X = 110
local STEP_Y = 94

type Art = {
	Icon: string,
	IconColor: Color3,
	ProgressColor: Color3,
	-- Share of the hexagon the picture takes (some were drawn smaller).
	Scale: number,
	-- Row of the honeycomb, and place in it counted in hexagons from the middle.
	Row: number,
	Column: number,
}

local function art(row: number, column: number, icon: string, color: Color3?, progress: Color3?, scale: number?): Art
	local iconColor = color or WHITE
	return {
		Icon = icon,
		IconColor = iconColor,
		ProgressColor = progress or iconColor,
		Scale = scale or 1,
		Row = row,
		Column = column,
	}
end

local rgb = Color3.fromRGB

-- Game art of the perks and where each one sits. The middle of row 2 is the points hexagon.
local PERK_ART: { [string]: Art } = {
	KillHeal = art(0, 0, "rbxassetid://116677009064224", nil, rgb(95, 255, 87)),

	TrueDamage = art(1, -2.5, "rbxassetid://93817972123138", rgb(33, 1, 190)),
	TargetLow = art(1, -1.5, "rbxassetid://120686839528129", rgb(234, 156, 255), nil, 0.9),
	FullHealth = art(1, -0.5, "rbxassetid://74971179125934", nil, rgb(95, 255, 87), 0.82),
	BuffRegen = art(1, 0.5, "rbxassetid://8530045132", rgb(255, 107, 107)),
	ResistWeapons = art(1, 1.5, "rbxassetid://8530041421", rgb(115, 159, 255)),
	ResistGeneral = art(1, 2.5, "rbxassetid://8530043939", rgb(0, 157, 255)),

	BuffWeapons = art(2, -2, "rbxassetid://8530046356", rgb(234, 156, 255)),
	LowHealth = art(2, -1, "rbxassetid://72453165337316", nil, rgb(255, 64, 30), 0.82),
	ResistHaki = art(2, 1, "rbxassetid://8530043322", rgb(170, 0, 255)),
	ResistAbilities = art(2, 2, "rbxassetid://8530043014", rgb(255, 53, 53)),

	AntiHeal = art(3, -1.5, "rbxassetid://84753377132265", nil, rgb(255, 0, 4), 0.82),
	BuffShave = art(3, -0.5, "rbxassetid://8530046939", rgb(255, 174, 93)),
	BuffRewards = art(3, 0.5, "rbxassetid://125727494661544", rgb(255, 247, 0), rgb(255, 193, 7), 0.65),
	BuffHealth = art(3, 1.5, "rbxassetid://8530151170", rgb(149, 255, 130), rgb(33, 255, 33)),

	BuffSpeed = art(4, -1, "rbxassetid://8530045639", rgb(255, 231, 94)),
	BuffDash = art(4, 0, "rbxassetid://8530047846", rgb(255, 255, 0)),
	BuffFishing = art(4, 1, "rbxassetid://119854494381853", rgb(255, 247, 0), rgb(255, 193, 7), 0.75),
}
local POINTS_ROW = 2
local ROWS = 5
local WIDEST_ROW = 6

local function getPerk(perks: any, name: string): (number, number)
	local perk = if type(perks) == "table" then perks[name] else nil
	local info = ExpertiseConfig.Perks[name]
	if type(perk) ~= "table" then
		return 0, info.Limit
	end
	return tonumber(perk.Value) or 0, math.max(1, tonumber(perk.Limit) or info.Limit)
end

-- Where a hexagon stands in the honeycomb frame.
local function cellPosition(row: number, column: number): UDim2
	return UDim2.new(0.5, column * STEP_X, 0, CELL / 2 + row * STEP_Y)
end

return function(scope: Scope, props: Props, menu: any): Instance
	local ExpertiseService = Knit.GetService("ExpertiseService")

	local level = Bind.data(scope, "Skills.Expertise.Level", 0)
	local exp = Bind.data(scope, "Skills.Expertise.Exp", 0)
	local perks = Bind.data(scope, "Expertise.Perks", {})

	-- The replicated values are read as they come: anything but a number counts zero.
	local levelNumber = scope:Computed(function(use): number
		return tonumber(use(level)) or 0
	end)
	local expNumber = scope:Computed(function(use): number
		return tonumber(use(exp)) or 0
	end)
	local maxed = scope:Computed(function(use): boolean
		return use(levelNumber) >= StatConfig.Caps.Expertise
	end)
	local spent = scope:Computed(function(use): number
		return ExpertiseConfig.GetSpentPoints(use(perks))
	end)
	local remaining = scope:Computed(function(use): number
		return use(levelNumber) - use(spent)
	end)

	-- Tooltip: the hovered perk name, RESPEC, or nil.
	local hovered: Fusion.Value<string?> = scope:Value(nil :: string?)
	local function hover(key: string): (hovering: boolean) -> ()
		return function(hovering: boolean)
			if hovering then
				hovered:set(key)
			elseif peek(hovered) == key then
				hovered:set(nil)
			end
		end
	end

	local cells: { Instance } = {}
	for _, name in ExpertiseConfig.PerkOrder do
		local perkArt = PERK_ART[name]
		if not perkArt then
			warn(`[UI] Expertise perk "{name}" has no place in the legacy honeycomb`)
			continue
		end

		-- The coloured copy of the hexagon is revealed from the bottom as points go in:
		-- its frame slides down by the empty share, the copy inside it back up.
		local empty = scope:Computed(function(use): number
			local value, limit = getPerk(use(perks), name)
			return 1 - math.clamp(value / limit, 0, 1)
		end)

		table.insert(
			cells,
			Kit.Image(scope, {
				Name = name,
				Image = HEXAGON,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = cellPosition(perkArt.Row, perkArt.Column),
				Size = UDim2.fromOffset(CELL, CELL),
				Children = {
					scope:New("Frame")({
						Name = "ProgressFrame",
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1,
						Position = scope:Computed(function(use): UDim2
							return UDim2.fromScale(0, use(empty))
						end),
						[Children] = {
							Kit.Image(scope, {
								Image = HEXAGON,
								Color = perkArt.ProgressColor,
								Transparency = 0.5,
								Size = UDim2.fromScale(1, 1),
								Position = scope:Computed(function(use): UDim2
									return UDim2.fromScale(0, -use(empty))
								end),
							}),
						},
					}),
					Kit.Image(scope, {
						Name = "Icon",
						Image = perkArt.Icon,
						Color = perkArt.IconColor,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(perkArt.Scale, perkArt.Scale),
						ZIndex = 2,
					}),
					Kit.Button(scope, {
						Name = "InvestPoint",
						Variant = "Ghost",
						Text = "",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
						OnHover = hover(name),
						OnClick = function()
							ExpertiseService.Invest:Fire(name)
						end,
					}),
				} :: { any },
			})
		)
	end

	-- The middle hexagon: the points left to spend, greyed once there are none. Pressing
	-- it asks for a respec.
	table.insert(
		cells,
		Kit.Image(scope, {
			Name = "Points",
			Image = POINTS_HEXAGON,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = cellPosition(POINTS_ROW, 0),
			Size = UDim2.fromOffset(CELL, CELL),
			Color = scope:Computed(function(use): Color3
				return if use(remaining) > 0 then POINTS_COLOR else NO_POINTS_COLOR
			end),
			Children = {
				Kit.Label(scope, {
					Name = "Label",
					TextSize = Kit.TextSize.Heading,
					Fit = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.6, 0.6),
					ZIndex = 2,
					Text = scope:Computed(function(use): string
						return if use(remaining) > 0 then tostring(use(remaining)) else ""
					end),
				}),
				Kit.Button(scope, {
					Name = "RespecPoints",
					Variant = "Ghost",
					Text = "",
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
					OnHover = hover(RESPEC),
					OnClick = function()
						ExpertiseService.Respec:Fire()
					end,
				}),
			} :: { any },
		})
	)

	-- The perk tooltip mirrors the hovered hexagon and follows its value while it is up.
	local tip = scope:Computed(function(use): any
		local key = use(hovered)
		if not key or key == RESPEC then
			return nil
		end
		local value, limit = getPerk(use(perks), key)
		local perkArt = PERK_ART[key]
		return {
			Description = ExpertiseConfig.Perks[key].Description,
			Value = value,
			Limit = limit,
			Icon = perkArt.Icon,
			IconColor = perkArt.IconColor,
			ProgressColor = perkArt.ProgressColor,
		}
	end)
	local function showTip()
		local perk = peek(tip)
		if perk then
			Tooltip.showPerk(perk)
		else
			Tooltip.hidePerk()
		end
		if peek(hovered) == RESPEC then
			Tooltip.showPerkPoints()
		else
			Tooltip.hidePerkPoints()
		end
	end
	scope:Observer(tip):onChange(showTip)
	scope:Observer(hovered):onChange(showTip)
	table.insert(scope, function()
		Tooltip.hidePerk()
		Tooltip.hidePerkPoints()
	end)

	-- MouseLeave never fires for a button that disappears under the cursor.
	local visible = scope:Computed(function(use): boolean
		return use(props.Visible) == true
	end)
	scope:Observer(visible):onChange(function()
		if not peek(visible) then
			hovered:set(nil)
		end
	end)
	scope:Observer(menu.Selected):onChange(function()
		hovered:set(nil)
	end)

	return Kit.Panel(scope, {
		Name = props.Name or "Expertise",
		Image = Kit.Images.ParchmentAlt,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
		Visible = visible,
		Children = Kit.Stack(scope, {
			Size = UDim2.fromScale(1, 1),
			Gap = Kit.Space.M,
			Padding = Kit.Space.L,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Children = {
				Kit.Label(scope, {
					Name = "Header",
					Text = "Expertise",
					TextSize = Kit.TextSize.Title,
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
				}),
				Kit.Well(scope, {
					Name = "Level",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(LEVEL_SIZE.X, LEVEL_SIZE.Y),
					Color = LEVEL_COLOR,
					Transparency = 0.7,
					Children = Kit.Label(scope, {
						TextSize = Kit.TextSize.Heading,
						Size = UDim2.fromScale(1, 1),
						Text = scope:Computed(function(use): string
							return tostring(use(levelNumber))
						end),
					}),
				}),
				Kit.Bar(scope, {
					Name = "Bar",
					LayoutOrder = 3,
					Size = UDim2.fromOffset(LEVEL_SIZE.X, BAR_HEIGHT),
					Color = EXP_COLOR,
					Value = scope:Computed(function(use): number
						if use(maxed) then
							return 1
						end
						local requirement = StatConfig.GetExpRequirement("Expertise", use(levelNumber))
						return if requirement > 0 then use(expNumber) / requirement else 0
					end),
					Text = scope:Computed(function(use): string
						if use(maxed) then
							return "MAX"
						end
						return `{use(expNumber)} / {StatConfig.GetExpRequirement("Expertise", use(levelNumber))}`
					end),
				}),
				scope:New("Frame")({
					Name = "Investments",
					BackgroundTransparency = 1,
					LayoutOrder = 4,
					Size = UDim2.fromOffset(WIDEST_ROW * STEP_X, (ROWS - 1) * STEP_Y + CELL),
					[Children] = cells,
				}),
			},
		}),
	})
end
