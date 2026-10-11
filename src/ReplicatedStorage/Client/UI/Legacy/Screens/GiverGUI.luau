--!strict
--[[
	The prompt of a fruit in hand: clicking with a fruit equipped lists what can be done
	with it. The first row (the fruit's name) eats it, one row per player within reach
	gives it to that player, the Drop button drops it and the X closes the prompt.

	The old rounded blue plate under the top of the screen, as a small list: Drop and the
	X in a row across its top (they hung half outside its corners), then the white rows,
	all the same height. The plate grows with the list.

	Every option is a bare request: the server acts on the fruit actually held and
	checks the receiver's distance itself.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local HeldTool = require(ReplicatedStorage.Client.UI.Util.HeldTool)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local FRUIT_ATTRIBUTE = "FruitItem"
-- Same reach the server allows for giving.
local GIVE_RANGE = 10

local PLATE_IMAGE = "rbxassetid://90291183096901"
local PLATE_COLOR = Color3.fromRGB(131, 181, 255)
local PLATE_SLICE = Rect.new(50, 50, 50, 50)
local DROP_IMAGE = "rbxassetid://89243894789752"
local FRUIT_COLOR = Color3.fromRGB(158, 149, 255)

-- Design pixels.
local WIDTH = 480
local PADDING = Kit.Space.L
local HEADER_HEIGHT = 40
local ROW_HEIGHT = 44
local ROW_GAP = Kit.Space.XS
local DROP_WIDTH = 140

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

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
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

		local plate = Kit.Panel(scope, {
			Name = "ImageLabel",
			Image = PLATE_IMAGE,
			ImageColor = PLATE_COLOR,
			Padding = PADDING,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.25),
			Visible = open,
			-- One row for the fruit, one per player within reach.
			Size = scope:Computed(function(use): UDim2
				local rows = 1 + #use(nearby)
				return UDim2.fromOffset(
					WIDTH,
					2 * PADDING + HEADER_HEIGHT + Kit.Space.S + rows * ROW_HEIGHT + (rows - 1) * ROW_GAP
				)
			end),
			Children = {
				Kit.Button(scope, {
					Name = "Drop",
					Text = "Drop",
					Variant = "Blue",
					Size = UDim2.fromOffset(DROP_WIDTH, HEADER_HEIGHT),
					OnClick = function()
						close()
						FruitService.Drop:Fire()
					end,
					Children = {
						Kit.Image(scope, {
							Image = DROP_IMAGE,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, Kit.Space.S, 0.5, 0),
							Size = UDim2.fromOffset(HEADER_HEIGHT - Kit.Space.M, HEADER_HEIGHT - Kit.Space.M),
							ZIndex = 3,
						}),
					},
				}),
				Kit.Button(scope, {
					Name = "Close",
					Text = "X",
					Variant = "Red",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
					OnClick = close,
				}),

				Kit.Stack(scope, {
					Name = "Frame",
					Gap = ROW_GAP,
					Position = UDim2.fromOffset(0, HEADER_HEIGHT + Kit.Space.S),
					Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + Kit.Space.S)),
					Children = {
						Kit.Button(scope, {
							Name = "1",
							LayoutOrder = 0,
							Variant = "Box",
							TextColor = FRUIT_COLOR,
							Text = scope:Computed(function(use): string
								local tool = use(fruit)
								return if tool then tool.Name else ""
							end),
							Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
							OnClick = function()
								close()
								FruitService.Eat:Fire()
							end,
						}),
						scope:ForValues(nearby, function(_use, rowScope: any, other: Player)
							return Kit.Button(rowScope, {
								Name = other.Name,
								LayoutOrder = 1,
								Variant = "Box",
								Text = other.Name,
								Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
								OnClick = function()
									close()
									FruitService.Give:Fire(other)
								end,
							})
						end),
					} :: { any },
				}),
			},
		})
		-- The plate is a rounded square: stretched whole, its corners would smear.
		plate.ScaleType = Enum.ScaleType.Slice
		plate.SliceCenter = PLATE_SLICE
		plate.SliceScale = 0.5

		return Kit.Screen(scope, {
			Name = context.Name,
			-- Above the HUD, as the rework's prompt is.
			DisplayOrder = 5,
			Children = { plate },
		})
	end,
}
