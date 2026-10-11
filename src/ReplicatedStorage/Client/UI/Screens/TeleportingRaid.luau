--!strict
--[[
	Raid waiting room. Open while RaidController holds a lobby (it opens and closes this
	screen; the screen reads GetLobby and listens to Changed).

	Everyone sees the party, the countdown and Leave. The owner also sees the players of
	this server with an invite button each, a remove button next to every member and
	"Teleport" to leave before the countdown ends.

	The rows follow the lobby state and the countdown is computed from its EndsAt.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type Member = { UserId: number, Name: string }

local COUNTDOWN_REFRESH = 0.25
-- An invited player can be asked again after this long (the invitation may have been
-- declined). Only what the button shows: the server refuses sooner ones by itself
-- (RaidConfig.InviteRepeat, keep the two equal).
local INVITE_COOLDOWN = 30

local ROW_HEIGHT = 44
local TITLE_HEIGHT = 30
local FOOTER_HEIGHT = 52
local ACTION_SIZE = UDim2.fromOffset(104, 32)

return {
	Mount = function(scope: Scope, _gui: any, _context: any)
		local RaidController = Knit.GetController("RaidController")
		local localPlayer = Players.LocalPlayer

		local lobby = scope:Value(RaidController:GetLobby())
		-- Bumped when someone joins or leaves the server, to rebuild the invite list.
		local roster = scope:Value(0)
		local now = scope:Value(Workspace:GetServerTimeNow())
		local invited: Fusion.Value<{ [Player]: boolean }> = scope:Value({})

		local isOwner = scope:Computed(function(use): boolean
			local state = use(lobby)
			return state ~= nil and state.OwnerId == localPlayer.UserId
		end)

		local members = scope:Computed(function(use): { Member }
			local state = use(lobby)
			return if state then state.Members else {}
		end)

		local invitable = scope:Computed(function(use): { Player }
			use(roster)
			local state = use(lobby)
			local list: { Player } = {}
			if not state or state.OwnerId ~= localPlayer.UserId then
				return list
			end
			local inParty: { [number]: boolean } = {}
			for _, member in state.Members do
				inParty[member.UserId] = true
			end
			for _, player in Players:GetPlayers() do
				if player ~= localPlayer and not inParty[player.UserId] then
					table.insert(list, player)
				end
			end
			return list
		end)

		local alive = true
		local changed = RaidController.Changed:Connect(function(state: any)
			lobby:set(state)
		end)
		table.insert(scope, function()
			alive = false
			changed:Disconnect()
		end)
		table.insert(scope, Players.PlayerAdded:Connect(function()
			roster:set(Fusion.peek(roster) + 1)
		end))
		table.insert(scope, Players.PlayerRemoving:Connect(function()
			-- The leaving player is still listed while this event runs.
			task.defer(function()
				if alive then
					roster:set(Fusion.peek(roster) + 1)
				end
			end)
		end))

		-- Lives only while the screen is open.
		task.spawn(function()
			while alive do
				now:set(Workspace:GetServerTimeNow())
				task.wait(COUNTDOWN_REFRESH)
			end
		end)

		local function invite(player: Player)
			RaidController:Invite(player)

			local marked = table.clone(Fusion.peek(invited))
			marked[player] = true
			invited:set(marked)
			task.delay(INVITE_COOLDOWN, function()
				if alive then
					local cleared = table.clone(Fusion.peek(invited))
					cleared[player] = nil
					invited:set(cleared)
				end
			end)
		end

		local function row(rowScope: Scope, name: string, action: any?, order: number?): Instance
			return UI.Panel(rowScope, {
				Name = name,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Color = Theme.Colors.Raised,
				Radius = Theme.Radius.Small,
				Gradient = false,
				Children = {
					UI.Label(rowScope, {
						Name = "PlayerName",
						Text = name,
						Variant = "BodyBold",
						Scaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(Theme.Space.M, 0),
						Size = UDim2.new(1, -(Theme.Space.M * 2 + ACTION_SIZE.X.Offset), 1, 0),
					}),
					action,
				} :: { any },
			})
		end

		local actionPlace = {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Theme.Space.S, 0.5, 0),
		}

		local half = UDim2.new(0.5, -Theme.Space.S, 1, -(FOOTER_HEIGHT + Theme.Space.M))
		local listSize = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + Theme.Space.S))
		local listPosition = UDim2.fromOffset(0, TITLE_HEIGHT + Theme.Space.S)

		return UI.Screen(scope, {
			Name = "TeleportingRaid",
			DisplayOrder = 12,
			Children = {
				UI.Window(scope, {
					Name = "MainFrame",
					Title = scope:Computed(function(use): string
						local state = use(lobby)
						local quest = state and LegendaryConfig.Quests[state.Quest]
						return if quest then (string.gsub(quest.Title, "^Fight ", "")) else "Raid"
					end),
					Subtitle = scope:Computed(function(use): string
						local state = use(lobby)
						if not state then
							return ""
						end
						return `Teleporting in: {math.max(0, math.ceil(state.EndsAt - use(now)))}`
					end),
					Size = UDim2.fromOffset(820, 540),
					Children = {
						scope:New("Frame")({
							Name = "FrameParty",
							Size = scope:Computed(function(use): UDim2
								return if use(isOwner) then half else UDim2.new(1, 0, half.Y.Scale, half.Y.Offset)
							end),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								UI.Label(scope, {
									Name = "PartyTitle",
									Text = scope:Computed(function(use): string
										local state = use(lobby)
										return if state then `Party {#state.Members}/{state.PartySize}` else "Party 0/4"
									end),
									Variant = "Heading",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
								}),
								UI.Scroll(scope, {
									Name = "PartyList",
									Position = listPosition,
									Size = listSize,
									Children = scope:ForValues(members, function(use, rowScope: Scope, member: Member)
										local state = use(lobby)
										local leader = state ~= nil and member.UserId == state.OwnerId
										local action: any = nil
										if leader then
											action = UI.Badge(rowScope, {
												Name = "Leader",
												Text = "Leader",
												Color = Theme.Colors.Accent,
												Soft = true,
												AnchorPoint = actionPlace.AnchorPoint,
												Position = actionPlace.Position,
											})
										elseif use(isOwner) then
											action = UI.Button(rowScope, {
												Name = "Remove",
												Text = "Remove",
												Variant = "Danger",
												TextSize = Theme.TextSize.Small,
												AnchorPoint = actionPlace.AnchorPoint,
												Position = actionPlace.Position,
												Size = ACTION_SIZE,
												OnClick = function()
													local target = Players:GetPlayerByUserId(member.UserId)
													if target then
														RaidController:Kick(target)
													end
												end,
											})
										end
										-- The leader first, then the others.
										return row(rowScope, member.Name, action, if leader then 0 else 1)
									end),
								}),
							},
						}),

						scope:New("Frame")({
							Name = "PlayersListFrame",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = half,
							BackgroundTransparency = 1,
							Visible = isOwner,
							[Fusion.Children] = {
								UI.Label(scope, {
									Name = "Title",
									Text = "Player List",
									Variant = "Heading",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
								}),
								UI.Scroll(scope, {
									Name = "PlayerList",
									Position = listPosition,
									Size = listSize,
									Children = scope:ForValues(invitable, function(_use, rowScope: Scope, player: Player)
										local sent = rowScope:Computed(function(use): boolean
											return use(invited)[player] == true
										end)
										return row(
											rowScope,
											player.Name,
											UI.Button(rowScope, {
												Name = "Invite",
												Text = rowScope:Computed(function(use): string
													return if use(sent) then "Invited" else "Invite"
												end),
												TextSize = Theme.TextSize.Small,
												Disabled = sent,
												AnchorPoint = actionPlace.AnchorPoint,
												Position = actionPlace.Position,
												Size = ACTION_SIZE,
												OnClick = function()
													invite(player)
												end,
											})
										)
									end),
								}),
							},
						}),

						UI.Button(scope, {
							Name = "Leave",
							Text = "Leave",
							Variant = "Danger",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.fromOffset(220, FOOTER_HEIGHT),
							OnClick = function()
								RaidController:Leave()
							end,
						}),
						UI.Button(scope, {
							Name = "Teleport",
							Text = "Teleport",
							TextSize = Theme.TextSize.Heading,
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.fromScale(1, 1),
							Size = UDim2.fromOffset(280, FOOTER_HEIGHT),
							Visible = isOwner,
							OnClick = function()
								RaidController:Start()
							end,
						}),
					},
				}),
			},
		})
	end,
}
