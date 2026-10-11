--!strict
--[[
	The always-on HUD (legacy HealthBar): health with the shield drawn over its end, the
	haki bar under it, the status icons of the local character and the Beri counter.

	Everything is derived from the HUD state the UIController mirrors from character
	attributes. The legacy scripts waited in `while wait()` chains for ValueObjects and the
	status list was one BoolValue listener per status; here the icon list is
	Configs.StatusIconConfig and an icon shows while the attribute of that name is set.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local StatusIconConfig = require(ReplicatedStorage.Client.Configs.StatusIconConfig)

type Scope = Fusion.Scope<typeof(Fusion)>

local HAKI_TWEEN = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
-- Icons per row, and the gap between them as a fraction of the row width (legacy grid).
local ICON_FRACTION = 0.1
local ICON_GAP_FRACTION = 0.025
local LABEL_PIXELS_PER_CHARACTER = 7
local BERI_COLOR = Color3.fromRGB(255, 221, 85)

local localPlayer = Players.LocalPlayer

local function resolve(field: any, value: any): string
	if type(field) == "function" then
		return field(value)
	end
	return field or ""
end

local function bindStatusIcons(scope: Scope, statusFrame: Frame)
	local grid: UIGridLayout = Bind.find(statusFrame, "UIGridLayout")
	-- The template row lives under the grid layout, as in the legacy tree.
	local template: Frame = Bind.find(grid, "Effect")

	--[[
		The legacy cells were 10% x 10% of a frame 36 px tall, i.e. 3.6 px high slivers.
		Read as intended: square icons, ten per row.
	]]
	local function resize()
		local side = math.max(1, math.floor(statusFrame.AbsoluteSize.X * ICON_FRACTION))
		local gap = math.floor(statusFrame.AbsoluteSize.X * ICON_GAP_FRACTION)
		grid.CellSize = UDim2.fromOffset(side, side)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
	end
	Bind.connect(scope, statusFrame:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()

	local icons: { [string]: Frame } = {}
	local connections: { RBXScriptConnection } = {}
	local order = 0

	local function refresh(character: Model, definition: StatusIconConfig.StatusIcon)
		local existing = icons[definition.Status]
		if existing then
			icons[definition.Status] = nil
			existing:Destroy()
		end

		local value = character:GetAttribute(definition.Status)
		if value == nil or value == false then
			return
		end

		order += 1
		local icon = template:Clone()
		icon.Name = definition.Status
		icon.LayoutOrder = order

		local image = icon:FindFirstChildOfClass("ImageLabel") :: ImageLabel
		local label = icon:FindFirstChild("Label") :: TextLabel
		local text = resolve(definition.Text, value)
		image.Image = resolve(definition.Image, value)
		label.Text = text
		label.Size = UDim2.new(1, #text * LABEL_PIXELS_PER_CHARACTER, 1, 0)

		-- Connections die with the clone.
		image.MouseEnter:Connect(function()
			label.Visible = true
		end)
		image.MouseLeave:Connect(function()
			label.Visible = false
		end)

		icon.Parent = statusFrame
		icons[definition.Status] = icon
	end

	local function clear()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for status, icon in icons do
			icons[status] = nil
			icon:Destroy()
		end
	end

	local function bindCharacter(character: Model)
		clear()
		for _, definition in StatusIconConfig do
			table.insert(connections, character:GetAttributeChangedSignal(definition.Status):Connect(function()
				refresh(character, definition)
			end))
			refresh(character, definition)
		end
	end

	Bind.connect(scope, localPlayer.CharacterAdded, bindCharacter)
	-- The body is removed after a death and none follows until the next spawn.
	Bind.connect(scope, localPlayer.CharacterRemoving, clear)
	if localPlayer.Character then
		bindCharacter(localPlayer.Character)
	end
	table.insert(scope, clear)
end

return {
	Layout = "HealthBar",
	Persistent = true,

	Mount = function(scope: Scope, gui: ScreenGui)
		local state = Knit.GetController("UIController"):GetHudState()

		-- The bar sits where Roblox draws its own (legacy ReplicatedFirst.CoreGui).
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

		local frame: Frame = Bind.find(gui, "Frame")
		-- No bar on the spawn screen: without a character the HUD state keeps the values
		-- of the last body, so "has a character" is asked directly.
		local hasCharacter = scope:Value(LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			hasCharacter:set(character ~= nil)
		end))
		Bind.props(scope, frame, {
			Visible = scope:Computed(function(use)
				return use(hasCharacter) and use(state.Spawned)
			end),
		})

		local healthRatio = scope:Computed(function(use)
			local maxHealth = use(state.MaxHealth)
			return if maxHealth > 0 then math.clamp(use(state.Health) / maxHealth, 0, 1) else 0
		end)
		local shieldRatio = scope:Computed(function(use)
			local maxHealth = use(state.MaxHealth)
			return if maxHealth > 0 then math.clamp(use(state.Shield) / maxHealth, 0, 1) else 0
		end)

		Bind.props(scope, Bind.find(frame, "HealthBar"), {
			Size = scope:Computed(function(use)
				return UDim2.fromScale(use(healthRatio), 1)
			end),
		})
		-- The shield continues the health bar and is pushed back inside when it would overflow.
		Bind.props(scope, Bind.find(frame, "Shield"), {
			Position = scope:Computed(function(use)
				local shield = use(shieldRatio)
				return UDim2.fromScale(math.clamp(use(healthRatio), 0, 1 - shield), 0)
			end),
			Size = scope:Computed(function(use)
				return UDim2.fromScale(use(shieldRatio), 1)
			end),
		})
		Bind.props(scope, Bind.find(frame, "Label"), {
			Text = scope:Computed(function(use)
				return `{math.ceil(use(state.Health))}/{math.ceil(use(state.MaxHealth))}`
			end),
		})

		-- Haki bar: only for players who have haki (HakiMax is the haki level, doubled by Alice).
		local haki: Frame = Bind.find(frame, "Haki")
		local hakiFill: Frame = Bind.find(haki, "Frame")
		local hakiRatio = scope:Computed(function(use)
			local maxHaki = use(state.HakiMax)
			return if maxHaki > 0 then math.clamp(use(state.HakiBar) / maxHaki, 0, 1) else 0
		end)
		Bind.props(scope, haki, {
			Visible = scope:Computed(function(use)
				return use(state.HakiMax) > 0
			end),
		})

		local hakiTween: Tween? = nil
		local function tweenHaki()
			if hakiTween then
				hakiTween:Cancel()
			end
			local tween = TweenService:Create(hakiFill, HAKI_TWEEN, {
				Size = UDim2.fromScale(Fusion.peek(hakiRatio), 1),
			})
			hakiTween = tween
			tween:Play()
		end
		hakiFill.Size = UDim2.fromScale(Fusion.peek(hakiRatio), 1)
		scope:Observer(hakiRatio):onChange(tweenHaki)
		table.insert(scope, function()
			if hakiTween then
				hakiTween:Cancel()
			end
		end)

		-- Hovering the haki bar shows its percentage, kept live while the mouse stays on it.
		local hovering = false
		local function hakiText(): string
			return `{math.floor(Fusion.peek(hakiRatio) * 10000) / 100}%`
		end
		Bind.connect(scope, haki.MouseEnter, function()
			hovering = true
			Tooltip.show(hakiText())
		end)
		Bind.connect(scope, haki.MouseLeave, function()
			if hovering then
				hovering = false
				Tooltip.hide()
			end
		end)
		scope:Observer(hakiRatio):onChange(function()
			if hovering then
				Tooltip.show(hakiText())
			end
		end)

		bindStatusIcons(scope, Bind.find(frame, "Status"))

		-- The legacy HUD had no Beri counter of its own (it lived in the menu); this one
		-- replaces the placeholder HUD's.
		scope:New("TextLabel")({
			Name = "Beri",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 16, 1, -16),
			Size = UDim2.fromOffset(220, 26),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			TextColor3 = BERI_COLOR,
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
			Text = scope:Computed(function(use)
				return `$ {Bind.formatNumber(use(state.Beri))}`
			end),
			Parent = gui,
		})
	end,
}
