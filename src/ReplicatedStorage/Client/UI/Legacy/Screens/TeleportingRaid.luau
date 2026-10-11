--!strict
--[[
	Raid waiting room (legacy TeleportingRaid). Open while RaidController holds a lobby (it
	opens and closes this screen; the screen reads GetLobby and listens to Changed).

	Laid over the world as it was: the countdown at the top of the screen with the raid's
	name under it, the party on a burnt sheet at the left, Leave under it, and for the
	owner the players of this server on a second sheet at the right and "Teleport" in the
	middle of the screen.

	Everyone sees the party, the countdown and Leave. The owner also sees the list of
	players of this server with an Invite button each, a remove button next to every
	member and "Teleport" to leave before the countdown ends.

	The legacy script rebuilt its rows from a folder in ReplicatedStorage and showed a
	number the server fired every second; the rows follow the lobby state and the
	countdown is computed from its EndsAt. Its invite and remove buttons were bare green
	and red squares: they say what they do now, and the old screen never named the raid.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type Member = { UserId: number, Name: string }

local DISPLAY_ORDER = 12
local COUNTDOWN_REFRESH = 0.25
-- An invited player can be asked again after this long (the invitation may have been
-- declined). Only what the button shows: the server refuses sooner ones by itself
-- (RaidConfig.InviteRepeat, keep the two equal).
local INVITE_COOLDOWN = 30

-- Where the old screen had its pieces, as shares of the screen.
local HEADER_POSITION = UDim2.fromScale(0.5, 0.13)
local PARTY_POSITION = UDim2.fromScale(0.13, 0.531)
local PLAYERS_POSITION = UDim2.fromScale(0.857, 0.531)
local LEAVE_POSITION = UDim2.fromScale(0.13, 0.875)
local TELEPORT_POSITION = UDim2.fromScale(0.5, 0.5)

local HEADER_SIZE = Vector2.new(560, 92)
local SHEET_SIZE = Vector2.new(440, 540)
local TITLE_HEIGHT = 56
local ROW_HEIGHT = 48
local ACTION_HEIGHT = ROW_HEIGHT - 2 * Kit.Space.XS
local REMOVE_WIDTH = ACTION_HEIGHT
local INVITE_WIDTH = 116
local LEADER_WIDTH = 84
-- The small sheet a button lying on the world is laid on, and its margin around the button.
local LEAVE_SIZE = Vector2.new(170, 68)
local TELEPORT_SIZE = Vector2.new(320, 76)
local PLATE_MARGIN = 8

return {
	Mount = function(scope: Scope, _gui: any, _context: any)
		local RaidController = Knit.GetController("RaidController")
		local localPlayer = Players.LocalPlayer

		local lobby = scope:Value(RaidController:GetLobby())
		-- Bumped when someone joins or leaves the server, to rebuild the invite list.
		local roster = scope:Value(0)
		local now = scope:Value(Workspace:GetServerTimeNow())
		-- Players asked less than INVITE_COOLDOWN ago.
		local invited: Fusion.Value<{ [Player]: boolean }> = scope:Value({} :: { [Player]: boolean })

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
			if Fusion.peek(invited)[player] then
				return
			end
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

		-- A player's row: the name in its dark box, and what can be done about that player
		-- at the right end (`actionWidth` wide, 0 without one).
		local function row(rowScope: Scope, name: string, action: any?, actionWidth: number, order: number?): Instance
			local taken = if actionWidth > 0 then actionWidth + Kit.Space.S else 0
			return Kit.Well(rowScope, {
				Name = name,
				LayoutOrder = order,
				Transparency = 0.2,
				Color = Color3.fromRGB(60, 60, 60),
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Children = {
					rowScope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					Kit.Label(rowScope, {
						Name = "PlayerName",
						Text = name,
						Fit = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(Kit.Space.M, 0),
						Size = UDim2.new(1, -(2 * Kit.Space.M + taken), 1, 0),
					}),
					action,
				} :: { any },
			})
		end

		local actionAnchor = Vector2.new(1, 0.5)
		local actionPosition = UDim2.new(1, -Kit.Space.XS, 0.5, 0)

		-- A sheet with a title in a dark box and a list under it.
		local function sheet(name: string, position: UDim2, title: Fusion.UsedAs<string>, visible: any, rows: any): Instance
			return Kit.Panel(scope, {
				Name = name,
				Image = Kit.Images.Sheet,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = position,
				Size = UDim2.fromOffset(SHEET_SIZE.X, SHEET_SIZE.Y),
				Padding = Kit.Space.XL,
				Visible = visible,
				Children = {
					Kit.Well(scope, {
						Name = "Title",
						Transparency = 0.5,
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						Children = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							Kit.Label(scope, {
								Text = title,
								TextSize = Kit.TextSize.Heading,
								Fit = true,
								Size = UDim2.fromScale(1, 1),
							}),
						} :: { any },
					}),
					Kit.Scroll(scope, {
						Name = "List",
						Background = false,
						Gap = Kit.Space.XS,
						Padding = 0,
						Position = UDim2.fromOffset(0, TITLE_HEIGHT + Kit.Space.M),
						Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + Kit.Space.M)),
						Children = rows,
					}),
				},
			})
		end

		-- A button lying on the world, on its own piece of the sheet as the old ones were.
		local function plate(
			name: string,
			position: UDim2,
			size: Vector2,
			text: string,
			variant: Kit.Variant,
			visible: any,
			onClick: () -> ()
		): Instance
			return Kit.Panel(scope, {
				Name = name,
				Image = Kit.Images.Sheet,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = position,
				Size = UDim2.fromOffset(size.X, size.Y),
				Padding = PLATE_MARGIN,
				Visible = visible,
				Children = {
					Kit.Button(scope, {
						Name = "TextButton",
						Text = text,
						Variant = variant,
						TextSize = Kit.TextSize.Heading,
						Size = UDim2.fromScale(1, 1),
						OnClick = onClick,
					}),
				},
			})
		end

		return Kit.Screen(scope, {
			Name = "TeleportingRaid",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				Kit.Stack(scope, {
					Name = "TeleportTime",
					Gap = Kit.Space.XS,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = HEADER_POSITION,
					Size = UDim2.fromOffset(HEADER_SIZE.X, HEADER_SIZE.Y),
					Children = {
						Kit.Label(scope, {
							Name = "Countdown",
							Text = scope:Computed(function(use): string
								local state = use(lobby)
								if not state then
									return ""
								end
								return `Teleporting in: {math.max(0, math.ceil(state.EndsAt - use(now)))}`
							end),
							TextSize = Kit.TextSize.Title,
							Size = UDim2.new(1, 0, 0, 48),
							LayoutOrder = 1,
						}),
						Kit.Label(scope, {
							Name = "RaidName",
							Text = scope:Computed(function(use): string
								local state = use(lobby)
								local quest = state and LegendaryConfig.Quests[state.Quest]
								return if quest then (string.gsub(quest.Title, "^Fight ", "")) else "Raid"
							end),
							TextSize = Kit.TextSize.Heading,
							Color = Kit.Colors.Gold,
							Fit = true,
							Size = UDim2.new(1, 0, 0, 40),
							LayoutOrder = 2,
						}),
					},
				}),

				-- Named "Window": a window for the gamepad; like the rework's it has no close
				-- button (Leave is one).
				sheet(
					"Window",
					PARTY_POSITION,
					scope:Computed(function(use): string
						local state = use(lobby)
						return if state then `Party {#state.Members}/{state.PartySize}` else "Party 0/4"
					end),
					true,
					scope:ForValues(members, function(use, rowScope: Scope, member: Member)
						local state = use(lobby)
						local leader = state ~= nil and member.UserId == state.OwnerId
						local action: any = nil
						local width = 0
						if leader then
							width = LEADER_WIDTH
							action = Kit.Label(rowScope, {
								Name = "Leader",
								Text = "Leader",
								TextSize = Kit.TextSize.Small,
								Color = Kit.Colors.Gold,
								TextXAlignment = Enum.TextXAlignment.Right,
								AnchorPoint = actionAnchor,
								Position = UDim2.new(1, -Kit.Space.M, 0.5, 0),
								Size = UDim2.fromOffset(LEADER_WIDTH, ACTION_HEIGHT),
							})
						elseif use(isOwner) then
							width = REMOVE_WIDTH
							action = Kit.Button(rowScope, {
								Name = "Remove",
								Text = "X",
								Variant = "Red",
								AnchorPoint = actionAnchor,
								Position = actionPosition,
								Size = UDim2.fromOffset(REMOVE_WIDTH, ACTION_HEIGHT),
								OnClick = function()
									local target = Players:GetPlayerByUserId(member.UserId)
									if target then
										RaidController:Kick(target)
									end
								end,
							})
						end
						-- The leader first, then the others.
						return row(rowScope, member.Name, action, width, if leader then 0 else 1)
					end)
				),

				sheet(
					"PlayersListFrame",
					PLAYERS_POSITION,
					"Player List",
					isOwner,
					scope:ForValues(invitable, function(_use, rowScope: Scope, player: Player)
						local sent = rowScope:Computed(function(use): boolean
							return use(invited)[player] == true
						end)
						return row(
							rowScope,
							player.Name,
							Kit.Button(rowScope, {
								Name = "Invite",
								Text = rowScope:Computed(function(use): string
									return if use(sent) then "Invited" else "Invite"
								end),
								Variant = "Green",
								TextSize = Kit.TextSize.Small,
								-- Grey and deaf until the player can be asked again.
								Disabled = sent,
								AnchorPoint = actionAnchor,
								Position = actionPosition,
								Size = UDim2.fromOffset(INVITE_WIDTH, ACTION_HEIGHT),
								OnClick = function()
									invite(player)
								end,
							}),
							INVITE_WIDTH
						)
					end)
				),

				plate("LeaveFrame", LEAVE_POSITION, LEAVE_SIZE, "Leave", "Red", true, function()
					RaidController:Leave()
				end),
				plate("ReadyButtonFrame", TELEPORT_POSITION, TELEPORT_SIZE, "Teleport", "Green", isOwner, function()
					RaidController:Start()
				end),
			},
		})
	end,
}
