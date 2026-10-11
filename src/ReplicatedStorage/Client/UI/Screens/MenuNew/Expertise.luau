--!strict
--[[
	Talents > Expertise: level, exp bar, points left, the perk grid and the respec button.
	Built by the Inventory part (which owns the Talents sub-tabs) while its sub-tab is open:

		Expertise(scope): Instance      -- fills its parent

	A perk card sends the perk name (ExpertiseService.Invest), Respec a bare request; the
	server owns points, limits and the respec cost. Hovering a perk shows its tooltip
	(Tooltip.showPerk), hovering Respec the points one.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local peek = Fusion.peek

local RESPEC = "Respec"
local HEADER_HEIGHT = 84
local CELL = Vector2.new(126, 150)

type Art = { Icon: string, IconColor: Color3, ProgressColor: Color3 }

local WHITE = Color3.new(1, 1, 1)

local function art(icon: string, color: Color3?, progress: Color3?): Art
	local iconColor = color or WHITE
	return { Icon = icon, IconColor = iconColor, ProgressColor = progress or iconColor }
end

-- Game art of the perks: icon, its tint and the colour of its progress.
local PERK_ART: { [string]: Art } = {
	ResistWeapons = art("rbxassetid://8530041421", Color3.fromRGB(115, 159, 255)),
	ResistAbilities = art("rbxassetid://8530043014", Color3.fromRGB(255, 53, 53)),
	ResistHaki = art("rbxassetid://8530043322", Color3.fromRGB(170, 0, 255)),
	ResistGeneral = art("rbxassetid://8530043939", Color3.fromRGB(0, 157, 255)),
	BuffHealth = art("rbxassetid://8530151170", Color3.fromRGB(149, 255, 130), Color3.fromRGB(33, 255, 33)),
	BuffRegen = art("rbxassetid://8530045132", Color3.fromRGB(255, 107, 107)),
	BuffSpeed = art("rbxassetid://8530045639", Color3.fromRGB(255, 231, 94)),
	BuffWeapons = art("rbxassetid://8530046356", Color3.fromRGB(234, 156, 255)),
	BuffShave = art("rbxassetid://8530046939", Color3.fromRGB(255, 174, 93)),
	BuffDash = art("rbxassetid://8530047846", Color3.fromRGB(255, 255, 0)),
	BuffRewards = art("rbxassetid://125727494661544", Color3.fromRGB(255, 247, 0), Color3.fromRGB(255, 193, 7)),
	AntiHeal = art("rbxassetid://84753377132265", nil, Color3.fromRGB(255, 0, 4)),
	BuffFishing = art("rbxassetid://119854494381853", Color3.fromRGB(255, 247, 0), Color3.fromRGB(255, 193, 7)),
	FullHealth = art("rbxassetid://74971179125934", nil, Color3.fromRGB(95, 255, 87)),
	KillHeal = art("rbxassetid://116677009064224", nil, Color3.fromRGB(95, 255, 87)),
	LowHealth = art("rbxassetid://72453165337316", nil, Color3.fromRGB(255, 64, 30)),
	TargetLow = art("rbxassetid://120686839528129", Color3.fromRGB(234, 156, 255)),
	TrueDamage = art("rbxassetid://93817972123138", Color3.fromRGB(33, 1, 190)),
}
local NO_ART: Art = art("", nil, Theme.Colors.Primary)

-- "ResistWeapons" -> "Resist Weapons"
local function displayName(perk: string): string
	return (string.gsub(perk, "(%l)(%u)", "%1 %2"))
end

local function getPerk(perks: any, name: string): (number, number)
	local perk = if type(perks) == "table" then perks[name] else nil
	local info = ExpertiseConfig.Perks[name]
	if type(perk) ~= "table" then
		return 0, info.Limit
	end
	return tonumber(perk.Value) or 0, math.max(1, tonumber(perk.Limit) or info.Limit)
end

return function(scope: Scope): Instance
	local ExpertiseService = Knit.GetService("ExpertiseService")

	local level = Bind.data(scope, "Skills.Expertise.Level", 0)
	local exp = Bind.data(scope, "Skills.Expertise.Exp", 0)
	local perks = Bind.data(scope, "Expertise.Perks", {})

	local maxed = scope:Computed(function(use): boolean
		return (tonumber(use(level)) or 0) >= StatConfig.Caps.Expertise
	end)
	local spent = scope:Computed(function(use): number
		return ExpertiseConfig.GetSpentPoints(use(perks))
	end)
	local remaining = scope:Computed(function(use): number
		return (tonumber(use(level)) or 0) - use(spent)
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

	local cards: { Instance } = {}
	for order, name in ExpertiseConfig.PerkOrder do
		local perkArt = PERK_ART[name] or NO_ART
		local ratio = scope:Computed(function(use): number
			local value, limit = getPerk(use(perks), name)
			return math.clamp(value / limit, 0, 1)
		end)

		table.insert(
			cards,
			UI.Card(scope, {
				Name = name,
				LayoutOrder = order,
				Title = displayName(name),
				Caption = scope:Computed(function(use): string
					local value, limit = getPerk(use(perks), name)
					return `{value} / {limit}`
				end),
				CaptionColor = perkArt.ProgressColor,
				Image = perkArt.Icon,
				ImageColor = perkArt.IconColor,
				Selected = scope:Computed(function(use): boolean
					return use(ratio) >= 1
				end),
				OnHover = hover(name),
				OnClick = function()
					ExpertiseService.Invest:Fire(name)
				end,
				Children = UI.ProgressBar(scope, {
					Name = "Progress",
					Value = ratio,
					Color = perkArt.ProgressColor,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -Theme.Space.XS),
					Size = UDim2.new(1, -Theme.Space.S, 0, 8),
				}),
			})
		)
	end

	-- The perk tooltip mirrors the hovered card and follows its value while it is up.
	local tip = scope:Computed(function(use): any
		local key = use(hovered)
		if not key or key == RESPEC then
			return nil
		end
		local value, limit = getPerk(use(perks), key)
		local perkArt = PERK_ART[key] or NO_ART
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
	-- A card that disappears under the cursor never reports the mouse leaving.
	table.insert(scope, function()
		Tooltip.hidePerk()
		Tooltip.hidePerkPoints()
	end)

	local respecWidth = 120
	local levelWidth = 150
	return scope:New("Frame")({
		Name = "Expertise",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		[Fusion.Children] = {
			UI.Panel(scope, {
				Name = "Header",
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				Padding = Theme.Space.M,
				Children = {
					UI.Label(scope, {
						Text = "Expertise",
						Variant = "Small",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.fromOffset(levelWidth, 18),
					}),
					UI.Label(scope, {
						Name = "Level",
						Variant = "Title",
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(0, 22),
						Size = UDim2.fromOffset(levelWidth, 36),
						Text = scope:Computed(function(use): string
							return `Level {use(level)}`
						end),
					}),
					UI.Label(scope, {
						Name = "Points",
						Variant = "Small",
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(levelWidth, 0),
						Size = UDim2.new(1, -(levelWidth + respecWidth + Theme.Space.M), 0, 18),
						Color = scope:Computed(function(use): Color3
							return if use(remaining) > 0 then Theme.Colors.Success else Theme.Colors.TextMuted
						end),
						Text = scope:Computed(function(use): string
							local points = use(remaining)
							if points <= 0 then
								return "No points to spend"
							end
							return if points == 1 then "1 point to spend" else `{points} points to spend`
						end),
					}),
					UI.ProgressBar(scope, {
						Name = "Bar",
						Position = UDim2.fromOffset(levelWidth, 28),
						Size = UDim2.new(1, -(levelWidth + respecWidth + Theme.Space.M), 0, 26),
						Color = Theme.Colors.Primary,
						Value = scope:Computed(function(use): number
							if use(maxed) then
								return 1
							end
							local requirement = StatConfig.GetExpRequirement("Expertise", tonumber(use(level)) or 0)
							return if requirement > 0 then (tonumber(use(exp)) or 0) / requirement else 0
						end),
						Text = scope:Computed(function(use): string
							if use(maxed) then
								return "MAX"
							end
							local requirement = StatConfig.GetExpRequirement("Expertise", tonumber(use(level)) or 0)
							return `{use(exp)} / {requirement}`
						end),
					}),
					UI.Button(scope, {
						Name = "RespecPoints",
						Text = "Respec",
						Variant = "Secondary",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(respecWidth, 44),
						OnHover = hover(RESPEC),
						OnClick = function()
							ExpertiseService.Respec:Fire()
						end,
					}),
				},
			}),
			UI.Scroll(scope, {
				Name = "Investments",
				Position = UDim2.fromOffset(0, HEADER_HEIGHT + Theme.Space.M),
				Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + Theme.Space.M)),
				CellSize = CELL,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Children = cards,
			}),
		},
	})
end
