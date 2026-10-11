--!strict
--[[
	Custom player list (legacy Core_i7), top-right corner: one row per player with a rank
	badge, the top 100 / legendary star, the name and the bounty, sorted by bounty.

	Everything shown comes from Player attributes (PlayerListService, SettingsService,
	LeaderboardService): other players' data is not replicated. A player who hides their
	bounty shows "-" and sinks to the bottom, as in the legacy list.

	The generated layout only has the container and the "show" button: the row template
	and the "hide" button were children of the legacy LocalScript and were not exported,
	so both are built here.

	The ScreenGui is named Core_i7: SettingsController enables / disables it from
	Settings.Player_List. The engine's own list stays off either way, as in the legacy game.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local RankConfig = require(ReplicatedStorage.Shared.Configs.RankConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)

type Scope = Fusion.Scope<typeof(Fusion)>

local ATTRIBUTES = RankConfig.Attributes

local ROW_COLOR = Color3.fromRGB(0, 0, 0)
local ROW_TRANSPARENCY = 0.5
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local BOUNTY_WIDTH = 80
local GAP = 2
local ICON_SIZE = 16
local ICON_PADDING = 4
local HIDDEN_BOUNTY_TEXT = "-"
-- LayoutOrder is a 32-bit integer.
local MAX_ORDER = 2 ^ 31 - 1
local TOGGLE_IMAGE = "http://www.roblox.com/asset/?id=5648080970"

local localPlayer = Players.LocalPlayer

local function buildRow(scope: Scope, player: Player, viewerRank: Fusion.Value<any>): Frame
	local bounty = Bind.attribute(scope, player, ATTRIBUTES.Bounty, nil)
	local hideBounty = Bind.attribute(scope, player, ATTRIBUTES.HideBounty, false)
	local legendary = Bind.attribute(scope, player, ATTRIBUTES.Legendary, false)
	local top = Bind.attribute(scope, player, ATTRIBUTES.Top, false)
	local rank = Bind.attribute(scope, player, ATTRIBUTES.Rank, nil)
	local tester = Bind.attribute(scope, player, ATTRIBUTES.Tester, nil)
	local hidden = Bind.attribute(scope, player, ATTRIBUTES.Hidden, false)

	local shownBounty = scope:Computed(function(use): number?
		local value = use(bounty)
		return if use(hideBounty) ~= true and type(value) == "number" then value else nil
	end)

	-- Moderator, owner, then the tester ranks: the legacy order.
	local badge = scope:Computed(function(use): string?
		local staff = use(rank)
		if staff == "Mod" or staff == "Owner" then
			return staff
		end
		local value = use(tester)
		return if type(value) == "string" and RankConfig.BadgeColors[value] then value else nil
	end)

	local starColor = scope:Computed(function(use): Color3?
		if use(top) == true then
			return if use(hideBounty) == true then RankConfig.StarLegendaryColor else RankConfig.StarTopColor
		elseif use(legendary) == true then
			return RankConfig.StarLegendaryColor
		end
		return nil
	end)

	local iconCount = scope:Computed(function(use): number
		return (if use(badge) then 1 else 0) + (if use(starColor) then 1 else 0)
	end)

	return scope:New("Frame")({
		Name = player.Name,
		BackgroundTransparency = 1,
		-- Hidden staff are listed for owners only.
		Visible = scope:Computed(function(use)
			return use(hidden) ~= true or use(viewerRank) == "Owner" or player == localPlayer
		end),
		LayoutOrder = scope:Computed(function(use)
			local value = use(shownBounty)
			return if value then -math.clamp(math.floor(value), 0, MAX_ORDER) else 1
		end),

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "BGFrame",
				Size = UDim2.new(1, -(BOUNTY_WIDTH + GAP), 1, 0),
				BackgroundColor3 = ROW_COLOR,
				BackgroundTransparency = ROW_TRANSPARENCY,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("ImageLabel")({
						Name = "MembershipIcon",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, ICON_PADDING, 0.5, 0),
						Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
						BackgroundTransparency = 1,
						Image = RankConfig.BadgeIcon,
						ImageColor3 = scope:Computed(function(use)
							local name = use(badge)
							return if name then RankConfig.BadgeColors[name] else TEXT_COLOR
						end),
						Visible = scope:Computed(function(use)
							return use(badge) ~= nil
						end),
					}),
					-- The legacy script cloned the badge for the star and left it on top of
					-- the original, so a ranked top-100 player lost their badge. It sits
					-- beside it here.
					scope:New("ImageLabel")({
						Name = "MembershipClone",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = scope:Computed(function(use)
							local offset = if use(badge) then ICON_SIZE + ICON_PADDING else 0
							return UDim2.new(0, ICON_PADDING + offset, 0.5, 0)
						end),
						Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
						BackgroundTransparency = 1,
						Image = RankConfig.StarIcon,
						ImageColor3 = scope:Computed(function(use)
							return use(starColor) or TEXT_COLOR
						end),
						Visible = scope:Computed(function(use)
							return use(starColor) ~= nil
						end),
					}),
					scope:New("TextLabel")({
						Name = "PlayerName",
						Position = scope:Computed(function(use)
							return UDim2.fromOffset(ICON_PADDING + use(iconCount) * (ICON_SIZE + ICON_PADDING), 0)
						end),
						Size = scope:Computed(function(use)
							local taken = ICON_PADDING * 2 + use(iconCount) * (ICON_SIZE + ICON_PADDING)
							return UDim2.new(1, -taken, 1, 0)
						end),
						BackgroundTransparency = 1,
						FontFace = FONT,
						Text = player.Name,
						TextColor3 = TEXT_COLOR,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Bounty",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, BOUNTY_WIDTH, 1, 0),
				BackgroundColor3 = ROW_COLOR,
				BackgroundTransparency = ROW_TRANSPARENCY,
				BorderSizePixel = 0,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "StatText",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						FontFace = FONT,
						Text = scope:Computed(function(use)
							local value = use(shownBounty)
							return if value then tostring(math.floor(value)) else HIDDEN_BOUNTY_TEXT
						end),
						TextColor3 = TEXT_COLOR,
						TextSize = 16,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),
		},
	}) :: any
end

return {
	Layout = "Corei7",
	Persistent = true,

	Mount = function(scope: Scope, gui: ScreenGui)
		local container: Frame = Bind.find(gui, "PlayerListContainer")
		local showButton: ImageButton = Bind.find(gui, "ShowButton")

		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)

		local players = scope:Value(Players:GetPlayers())
		local collapsed = scope:Value(false)
		local viewerRank = Bind.attribute(scope, localPlayer, ATTRIBUTES.Rank, nil)

		local function refresh()
			players:set(Players:GetPlayers())
		end
		Bind.connect(scope, Players.PlayerAdded, refresh)
		-- The leaving player is still in GetPlayers while PlayerRemoving runs.
		Bind.connect(scope, Players.PlayerRemoving, function(leaving: Player)
			local remaining = Players:GetPlayers()
			local index = table.find(remaining, leaving)
			if index then
				table.remove(remaining, index)
			end
			players:set(remaining)
		end)

		-- A Folder keeps the button out of the grid: it is placed against the container.
		local hideButton = scope:New("ImageButton")({
			Name = "HideButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(-3, 1),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Image = TOGGLE_IMAGE,
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ImageTransparency = 0.5,
			[Fusion.OnEvent("Activated")] = function()
				collapsed:set(true)
			end,
		})

		Bind.props(scope, container, {
			Visible = scope:Computed(function(use)
				return not use(collapsed)
			end),
			[Fusion.Children] = {
				scope:New("Folder")({
					Name = "Ignore",
					[Fusion.Children] = { hideButton },
				}),
				scope:ForValues(players, function(_use, rowScope: any, player: Player)
					return buildRow(rowScope, player, viewerRank)
				end),
			},
		})

		Bind.props(scope, showButton, { Visible = collapsed })
		Bind.click(scope, showButton, function()
			collapsed:set(false)
		end)
	end,
}
