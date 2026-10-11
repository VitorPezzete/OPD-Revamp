--!strict
--[[
	The always-on HUD: health with the shield drawn over its end, the haki bar under it,
	and the status icons of the local character.

	Everything is derived from the HUD state the UIController mirrors from character
	attributes. A status icon shows while the character attribute named in
	Configs.StatusIconConfig is set; hovering it (or the haki bar) shows a tooltip.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local StatusIconConfig = require(ReplicatedStorage.Client.Configs.StatusIconConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

type StatusEntry = {
	Text: string,
	Image: string,
	Order: number,
}

local WIDTH = 560
local TOP_MARGIN = 8
local HEALTH_HEIGHT = 28
local HAKI_HEIGHT = 10
local ICON_SIZE = 36
local ICON_INSET = 6

local function resolve(field: any, value: any): string
	if type(field) == "function" then
		return field(value)
	end
	return field or ""
end

-- The statuses currently set on the local character, keyed by status name.
local function observeStatuses(scope: Scope): Fusion.Value<{ [string]: StatusEntry }>
	local active: Fusion.Value<{ [string]: StatusEntry }> = scope:Value({})
	local connections: { RBXScriptConnection } = {}
	local order = 0

	local function refresh(character: Model, definition: StatusIconConfig.StatusIcon)
		local current = Fusion.peek(active)
		local existing = current[definition.Status]
		local value = character:GetAttribute(definition.Status)

		local updated = table.clone(current)
		if value == nil or value == false then
			if not existing then
				return
			end
			updated[definition.Status] = nil
		else
			-- A status whose value changes keeps its place in the row.
			if not existing then
				order += 1
			end
			updated[definition.Status] = {
				Text = resolve(definition.Text, value),
				Image = resolve(definition.Image, value),
				Order = if existing then existing.Order else order,
			}
		end
		active:set(updated)
	end

	local function clear()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		active:set({})
	end

	table.insert(scope, LocalCharacter.Observe(function(character: Model?)
		clear()
		if not character then
			return
		end
		for _, definition in StatusIconConfig do
			table.insert(connections, character:GetAttributeChangedSignal(definition.Status):Connect(function()
				refresh(character, definition)
			end))
			refresh(character, definition)
		end
	end))
	table.insert(scope, clear)

	return active
end

--[[
	Health with the shield continuing it. The kit's ProgressBar overlay starts at the left
	edge; the shield has to start where the health ends and is pushed back inside when it
	would overflow, so this bar is built here.
]]
local function healthBar(scope: Scope, health: UsedAs<number>, shield: UsedAs<number>, text: UsedAs<string>): Frame
	local radius = UDim.new(0, Theme.Radius.Small)

	return scope:New("Frame")({
		Name = "Health",
		Size = UDim2.new(1, 0, 0, HEALTH_HEIGHT),
		BackgroundColor3 = Theme.Colors.HealthLost,
		BackgroundTransparency = Theme.Transparency.Hud,
		LayoutOrder = 1,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = radius }),
			scope:New("UIStroke")({ Color = Theme.Colors.Black, Thickness = Theme.Stroke.Thin }),
			scope:New("Frame")({
				Name = "Clip",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Fill",
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(health), 1)
						end),
						BackgroundColor3 = Theme.Colors.Health,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = radius }),
						},
					}),
					scope:New("Frame")({
						Name = "Shield",
						Position = scope:Computed(function(use): UDim2
							return UDim2.fromScale(math.clamp(use(health), 0, 1 - use(shield)), 0)
						end),
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(shield), 1)
						end),
						BackgroundColor3 = Theme.Colors.Shield,
						BackgroundTransparency = 0.2,
						ZIndex = 2,
						[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = radius }) },
					}),
				},
			}),
			UI.Label(scope, {
				Name = "Text",
				Text = text,
				Variant = "BodyBold",
				Color = Theme.Colors.White,
				TextSize = Theme.TextSize.Small,
				Size = UDim2.fromScale(1, 1),
				Outline = true,
				OutlineThickness = 1,
				OutlineTransparency = 0,
				OutlineColor = Theme.Colors.Black,
				ZIndex = 3,
			}),
		},
	}) :: any
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local state = Knit.GetController("UIController"):GetHudState()

		-- This bar replaces the one Roblox draws.
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)

		-- No HUD on the spawn screen: without a character the HUD state keeps the values
		-- of the last body, so "has a character" is asked directly.
		local hasCharacter = scope:Value(LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			hasCharacter:set(character ~= nil)
		end))
		local visible = scope:Computed(function(use): boolean
			return use(hasCharacter) and use(state.Spawned)
		end)

		local healthRatio = scope:Computed(function(use): number
			local maxHealth = use(state.MaxHealth)
			return if maxHealth > 0 then math.clamp(use(state.Health) / maxHealth, 0, 1) else 0
		end)
		local shieldRatio = scope:Computed(function(use): number
			local maxHealth = use(state.MaxHealth)
			return if maxHealth > 0 then math.clamp(use(state.Shield) / maxHealth, 0, 1) else 0
		end)
		local healthText = scope:Computed(function(use): string
			local shield = use(state.Shield)
			local text = `{Bind.formatNumber(math.ceil(use(state.Health)))} / {Bind.formatNumber(math.ceil(use(state.MaxHealth)))}`
			return if shield > 0 then `{text}  (+{Bind.formatNumber(math.ceil(shield))})` else text
		end)

		-- Haki bar: only for players who have haki (HakiMax is the haki level, doubled by Alice).
		local hasHaki = scope:Computed(function(use): boolean
			return use(state.HakiMax) > 0
		end)
		local hakiRatio = scope:Computed(function(use): number
			local maxHaki = use(state.HakiMax)
			return if maxHaki > 0 then math.clamp(use(state.HakiBar) / maxHaki, 0, 1) else 0
		end)
		local hakiBar = UI.ProgressBar(scope, {
			Name = "Haki",
			Value = hakiRatio,
			Color = Theme.Colors.Haki,
			TrackColor = Theme.Colors.Black,
			StrokeColor = Theme.Colors.Black,
			-- The bars show the value as it is: no sliding.
			Animated = false,
			Size = UDim2.new(1, 0, 0, HAKI_HEIGHT),
			Transparency = Theme.Transparency.Hud,
			Visible = hasHaki,
			LayoutOrder = 2,
		})

		-- Hovering the haki bar shows its percentage, kept live while the mouse stays on it.
		local hovering = false
		local function hakiText(): string
			return `Haki {math.floor(Fusion.peek(hakiRatio) * 10000) / 100}%`
		end
		local function leave()
			if hovering then
				hovering = false
				Tooltip.hide()
			end
		end
		Bind.connect(scope, hakiBar.MouseEnter, function()
			hovering = true
			Tooltip.show(hakiText())
		end)
		Bind.connect(scope, hakiBar.MouseLeave, leave)
		scope:Observer(hakiRatio):onChange(function()
			if hovering then
				Tooltip.show(hakiText())
			end
		end)
		-- A bar hidden under the cursor never fires MouseLeave.
		scope:Observer(scope:Computed(function(use): boolean
			return use(visible) and use(hasHaki)
		end)):onChange(leave)
		table.insert(scope, leave)

		local statuses = observeStatuses(scope)
		local statusIcons = scope:ForPairs(statuses, function(_use, itemScope: Scope, status: string, entry: StatusEntry)
			local icon = UI.Panel(itemScope, {
				Name = status,
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				LayoutOrder = entry.Order,
				Color = Theme.Colors.Grey,
				Stroke = Theme.Colors.Black,
				Transparency = Theme.Transparency.Hud,
				Radius = Theme.Radius.Small,
				Children = {
					if entry.Image ~= ""
						then UI.Image(itemScope, {
							Name = "Icon",
							Image = entry.Image,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(1, -ICON_INSET, 1, -ICON_INSET),
						})
						-- Statuses the old game never drew an icon for.
						else UI.Label(itemScope, {
							Name = "Icon",
							Text = "!",
							Variant = "Heading",
							Color = Theme.Colors.Accent,
							Size = UDim2.fromScale(1, 1),
						}),
				},
			})
			Tooltip.attach(itemScope, icon, entry.Text)
			return status, icon
		end)

		return UI.Screen(scope, {
			Name = "HealthBar",
			DisplayOrder = 1,
			-- Sits in the strip of the Roblox top bar, where the default health bar was.
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Hud",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, TOP_MARGIN),
					Size = UDim2.fromOffset(WIDTH, HEALTH_HEIGHT + HAKI_HEIGHT + ICON_SIZE * 2 + Theme.Space.XS * 3),
					BackgroundTransparency = 1,
					Visible = visible,
					[Fusion.Children] = {
						UI.Stack(scope, {
							Name = "Rows",
							Size = UDim2.fromScale(1, 1),
							Gap = Theme.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Children = {
								healthBar(scope, healthRatio, shieldRatio, healthText),
								hakiBar,
								UI.Stack(scope, {
									Name = "Status",
									Direction = "Horizontal",
									Size = UDim2.fromScale(1, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									Gap = Theme.Space.XS,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									Wraps = true,
									LayoutOrder = 3,
									Children = statusIcons,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
