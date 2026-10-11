--!strict
--[[
	The prompt of a fruit in hand: clicking with a fruit equipped lists what can be done
	with it. Eat it, give it to a player within reach (one button each), drop it, or
	close the prompt.

	Every option is a bare request: the server acts on the fruit actually held and
	checks the receiver's distance itself.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local HeldTool = require(ReplicatedStorage.Client.UI.Util.HeldTool)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local FRUIT_ATTRIBUTE = "FruitItem"
-- Same reach the server allows for giving.
local GIVE_RANGE = 10
local DROP_ICON = "rbxassetid://89243894789752"

local WIDTH = 380
local ROW = UDim2.new(1, 0, 0, 46)
local HEADER_HEIGHT = 36

local function getNearbyPlayers(): { Player }
	local nearby: { Player } = {}
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character
	local root = character and character.PrimaryPart
	if not root then
		return nearby
	end

	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= localPlayer and other.Character and other.Character.PrimaryPart
		if otherRoot and (otherRoot.Position - root.Position).Magnitude <= GIVE_RANGE then
			table.insert(nearby, other)
		end
	end
	return nearby
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local FruitService = Knit.GetService("FruitService")

		local held = HeldTool.observe(scope)
		local open = scope:Value(false)
		local nearby: Fusion.Value<{ Player }> = scope:Value({})

		local fruit = scope:Computed(function(use): Tool?
			local tool = use(held)
			return if tool and tool:GetAttribute(FRUIT_ATTRIBUTE) ~= nil then tool else nil
		end)

		local function close()
			open:set(false)
		end

		-- Clicking with the fruit in hand opens the prompt; putting it away closes it.
		local activation: RBXScriptConnection? = nil
		local function follow()
			if activation then
				activation:Disconnect()
				activation = nil
			end
			close()

			local tool = Fusion.peek(fruit)
			if tool then
				activation = tool.Activated:Connect(function()
					nearby:set(getNearbyPlayers())
					open:set(true)
				end)
			end
		end
		scope:Observer(fruit):onChange(follow)
		follow()
		table.insert(scope, function()
			if activation then
				activation:Disconnect()
			end
		end)

		return UI.Screen(scope, {
			Name = "GiverGUI",
			DisplayOrder = 5,
			Children = {
				UI.Panel(scope, {
					Name = "Prompt",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.25),
					Size = UDim2.fromOffset(WIDTH, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Color = Theme.Colors.Background,
					Transparency = Theme.Transparency.Hud,
					Stroke = Theme.Colors.BorderStrong,
					Radius = Theme.Radius.Large,
					Padding = Theme.Space.M,
					Visible = open,
					Children = {
						UI.Stack(scope, {
							Name = "Rows",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Gap = Theme.Space.S,
							Children = {
								scope:New("Frame")({
									Name = "Header",
									Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
									BackgroundTransparency = 1,
									LayoutOrder = 1,
									[Fusion.Children] = {
										UI.Label(scope, {
											Name = "Fruit",
											Text = scope:Computed(function(use): string
												local tool = use(fruit)
												return if tool then tool.Name else ""
											end),
											Variant = "Heading",
											Scaled = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											Size = UDim2.new(1, -(HEADER_HEIGHT + Theme.Space.S), 1, 0),
										}),
										UI.Button(scope, {
											Name = "Close",
											Text = "X",
											Variant = "Ghost",
											TextColor = Theme.Colors.Text,
											AnchorPoint = Vector2.new(1, 0),
											Position = UDim2.fromScale(1, 0),
											Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
											OnClick = close,
										}),
									},
								}),
								UI.Button(scope, {
									Name = "Eat",
									Text = "Eat",
									Size = ROW,
									LayoutOrder = 2,
									OnClick = function()
										close()
										FruitService.Eat:Fire()
									end,
								}),
								UI.Label(scope, {
									Name = "GiveTitle",
									Text = "Give to a player nearby",
									Variant = "Small",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, 20),
									LayoutOrder = 3,
									Visible = scope:Computed(function(use): boolean
										return #use(nearby) > 0
									end),
								}),
								UI.Stack(scope, {
									Name = "Players",
									Size = UDim2.fromScale(1, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									Gap = Theme.Space.S,
									LayoutOrder = 4,
									Visible = scope:Computed(function(use): boolean
										return #use(nearby) > 0
									end),
									Children = scope:ForValues(nearby, function(_use, rowScope: Scope, other: Player)
										return UI.Button(rowScope, {
											Name = other.Name,
											Text = other.Name,
											Variant = "Secondary",
											Size = ROW,
											OnClick = function()
												close()
												FruitService.Give:Fire(other)
											end,
										})
									end),
								}),
								UI.Button(scope, {
									Name = "Drop",
									Text = "Drop",
									Icon = DROP_ICON,
									Variant = "Danger",
									Size = ROW,
									LayoutOrder = 5,
									OnClick = function()
										close()
										FruitService.Drop:Fire()
									end,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
