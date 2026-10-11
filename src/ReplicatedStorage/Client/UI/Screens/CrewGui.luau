--!strict
--[[
	Crew menu.

	Without a crew: the create form, and the invite prompt when someone invited you.
	In a crew: three tabs.
	  Menu      name, logo, level and experience bar
	  Players   member list; pick a member, then promote / demote / kick (owner).
	            Picking yourself turns Kick into "leave" (or "disband" for the owner).
	  Upgrades  member slots, logo, name (owner, paid in Gems)

	Everything shown comes from the crew view the server sends (CrewController); the
	buttons only send intents through CrewService.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local CrewConfig = require(ReplicatedStorage.Shared.Configs.CrewConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type State<T> = Fusion.StateObject<T>
type Member = { UserId: number, Name: string, Role: string }
type Crew = {
	Id: string,
	Name: string,
	ImageId: string,
	Level: number,
	XP: number,
	MemberLimit: number,
	Members: { Member },
}
type Confirmation = { Text: string, Run: () -> () }
type Editor = { Title: string, Placeholder: string, Send: (text: string) -> () }

local ROLE_LABELS: { [string]: string } = { Owner = "Owner", CoOwner = "Co-Owner", Member = "Member" }
local ROLE_ORDER: { [string]: number } = { Owner = 0, CoOwner = 1, Member = 2 }
local ROLE_COLORS: { [string]: Color3 } = {
	Owner = Theme.Colors.Warning,
	CoOwner = Theme.Colors.Accent,
	Member = Theme.Colors.TextMuted,
}
local TABS = {
	{ Key = "Menu", Text = "Menu" },
	{ Key = "Players", Text = "Players" },
	{ Key = "Upgrades", Text = "Upgrades" },
}

local GEM_ICON = "rbxassetid://1954296071"
local UNTINTED = Color3.new(1, 1, 1)
local TAB_HEIGHT = 40
local FIELD_HEIGHT = 44
local MEMBER_HEIGHT = 46
local SIDE_WIDTH = 330
-- A button that sent a request stays disabled this long (the answer comes as a new crew view).
local SENT_SECONDS = 1

local localPlayer = Players.LocalPlayer

local function priceButton(scope: Scope, props: { [string]: any }): TextButton
	props.Icon = GEM_ICON
	props.IconColor = UNTINTED
	return UI.Button(scope, props :: any)
end

local function fieldLabel(scope: Scope, text: string, order: number): TextLabel
	return UI.Label(scope, {
		Text = text,
		Variant = "Small",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = order,
	})
end

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local CrewService = Knit.GetService("CrewService")
		local CrewController = Knit.GetController("CrewController")

		local crew: Fusion.Value<Crew?> = scope:Value(CrewController:GetCrew() :: Crew?)
		local invite = scope:Value(CrewController:GetInvite())
		local tab = scope:Value("Menu")
		local selected: Fusion.Value<Member?> = scope:Value(nil :: Member?)
		local confirmation: Fusion.Value<Confirmation?> = scope:Value(nil :: Confirmation?)
		-- The upgrade that is asking for text (logo, name), nil when none.
		local editor: Fusion.Value<Editor?> = scope:Value(nil :: Editor?)
		local sent = scope:Value(false)

		local crewName = scope:Value("")
		local crewImage = scope:Value("")
		local inviteName = scope:Value("")
		local editorText = scope:Value("")

		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)
		local function markSent()
			sent:set(true)
			task.delay(SENT_SECONDS, function()
				if mounted then
					sent:set(false)
				end
			end)
		end

		local crewConnection = CrewController.Changed:Connect(function(view: Crew?)
			crew:set(view)
			-- The picked member may be gone, or have another role now.
			local picked = Fusion.peek(selected)
			local stillThere: Member? = nil
			if view and picked then
				for _, member in view.Members do
					if member.UserId == picked.UserId then
						stillThere = member
						break
					end
				end
			end
			selected:set(stillThere)
			confirmation:set(nil)
		end)
		local inviteConnection = CrewController.InviteChanged:Connect(function(value: any)
			invite:set(value)
		end)
		table.insert(scope, function()
			crewConnection:Disconnect()
			inviteConnection:Disconnect()
		end)

		local hasCrew = scope:Computed(function(use): boolean
			return use(crew) ~= nil
		end)
		local myRole = scope:Computed(function(use): string?
			local view = use(crew)
			if view then
				for _, member in view.Members do
					if member.UserId == localPlayer.UserId then
						return member.Role
					end
				end
			end
			return nil
		end)
		local isOwner = scope:Computed(function(use): boolean
			return use(myRole) == "Owner"
		end)
		local canInvite = scope:Computed(function(use): boolean
			local role = use(myRole)
			return role == "Owner" or role == "CoOwner"
		end)
		local members = scope:Computed(function(use): { Member }
			local view = use(crew)
			return if view then view.Members else {}
		end)
		local selfSelected = scope:Computed(function(use): boolean
			local member = use(selected)
			return member ~= nil and member.UserId == localPlayer.UserId
		end)
		local confirming = scope:Computed(function(use): boolean
			return use(confirmation) ~= nil
		end)
		local notConfirming = scope:Computed(function(use): boolean
			return use(confirmation) == nil
		end)

		local function expRequired(view: Crew): number
			return math.ceil(CrewConfig.GetExpRequired(view.Level))
		end

		local function pageVisible(key: string): State<boolean>
			return scope:Computed(function(use): boolean
				return use(tab) == key
			end)
		end
		local pagePosition = UDim2.fromOffset(0, TAB_HEIGHT + Theme.Space.M)
		local pageSize = UDim2.new(1, 0, 1, -(TAB_HEIGHT + Theme.Space.M))

		-- No crew -----------------------------------------------------------------------
		local createView = scope:New("Frame")({
			Name = "Create",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(crew) == nil
			end),
			[Fusion.Children] = {
				UI.Stack(scope, {
					Name = "Form",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, Theme.Space.L),
					Size = UDim2.fromOffset(460, 330),
					Gap = Theme.Space.S,
					Children = {
						UI.Label(scope, {
							Text = "Create a crew",
							Variant = "Title",
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, 36),
							LayoutOrder = 1,
						}),
						UI.Label(scope, {
							Text = "You are not in a crew. Start your own, or ask a crew owner to invite you.",
							Variant = "Muted",
							TextSize = Theme.TextSize.Small,
							Wrapped = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, 44),
							LayoutOrder = 2,
						}),
						fieldLabel(scope, "Crew Name", 3),
						UI.TextInput(scope, {
							Name = "CrewName",
							Text = crewName,
							Placeholder = "Insert your crew name",
							MaxLength = CrewConfig.NameMaxLength,
							Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
							LayoutOrder = 4,
						}),
						fieldLabel(scope, "Image ID", 5),
						UI.TextInput(scope, {
							Name = "GroupID",
							Text = crewImage,
							Placeholder = "Insert your image ID",
							Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
							LayoutOrder = 6,
						}),
						priceButton(scope, {
							Name = "CreateButton",
							Text = `Create   {Bind.formatNumber(CrewConfig.CreatePrice)}`,
							Size = UDim2.new(1, 0, 0, 50),
							LayoutOrder = 7,
							Disabled = sent,
							OnClick = function()
								markSent()
								CrewService.Create:Fire(Fusion.peek(crewName), Fusion.peek(crewImage))
							end,
						}),
					},
				}),

				UI.Panel(scope, {
					Name = "Invite",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.new(1, 0, 0, 110),
					Color = Theme.Colors.Raised,
					Stroke = Theme.Colors.BorderStrong,
					Padding = Theme.Space.M,
					Visible = scope:Computed(function(use): boolean
						return use(invite) ~= nil and use(crew) == nil
					end),
					Children = {
						UI.Label(scope, {
							Text = scope:Computed(function(use): string
								local pending: any = use(invite)
								return if pending then `Do you want to join the {pending.CrewName} crew?` else ""
							end),
							Variant = "BodyBold",
							Scaled = true,
							Size = UDim2.new(1, 0, 0, 30),
						}),
						UI.Button(scope, {
							Name = "Decline",
							Text = "Decline",
							Variant = "Secondary",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.new(0.5, -Theme.Space.S / 2, 1, 0),
							Size = UDim2.fromOffset(200, 44),
							OnClick = function()
								CrewController:AnswerInvite(false)
							end,
						}),
						UI.Button(scope, {
							Name = "Confirm",
							Text = "Join",
							Variant = "Success",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0.5, Theme.Space.S / 2, 1, 0),
							Size = UDim2.fromOffset(200, 44),
							OnClick = function()
								CrewController:AnswerInvite(true)
							end,
						}),
					},
				}),
			},
		})

		-- Menu tab ----------------------------------------------------------------------
		local menuPage = scope:New("Frame")({
			Name = "Menu",
			Position = pagePosition,
			Size = pageSize,
			BackgroundTransparency = 1,
			Visible = pageVisible("Menu"),
			[Fusion.Children] = {
				UI.Image(scope, {
					Name = "CrewImage",
					Size = UDim2.fromOffset(260, 260),
					Background = Theme.Colors.Sunken,
					Radius = Theme.Radius.Large,
					Image = scope:Computed(function(use): string
						local view = use(crew)
						return if view and view.ImageId ~= "0" then `rbxassetid://{view.ImageId}` else ""
					end),
				}),
				UI.Stack(scope, {
					Name = "Info",
					Position = UDim2.fromOffset(260 + Theme.Space.XL, 0),
					Size = UDim2.new(1, -(260 + Theme.Space.XL), 0, 260),
					Gap = Theme.Space.M,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Children = {
						UI.Label(scope, {
							Name = "CrewName",
							Text = scope:Computed(function(use): string
								local view = use(crew)
								return if view then view.Name else ""
							end),
							Variant = "Display",
							Scaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, 56),
							LayoutOrder = 1,
						}),
						UI.Stack(scope, {
							Direction = "Horizontal",
							Gap = Theme.Space.S,
							LayoutOrder = 2,
							Children = {
								UI.Badge(scope, {
									Name = "CrewLvL",
									LayoutOrder = 1,
									Text = scope:Computed(function(use): string
										local view = use(crew)
										return `Level {if view then view.Level else 0}`
									end),
								}),
								UI.Badge(scope, {
									Name = "Members",
									LayoutOrder = 2,
									Soft = true,
									Color = Theme.Colors.Accent,
									Text = scope:Computed(function(use): string
										local view = use(crew)
										-- The owner does not use a member slot.
										return if view then `{#view.Members}/{view.MemberLimit + 1} members` else ""
									end),
								}),
								UI.Badge(scope, {
									Name = "Role",
									LayoutOrder = 3,
									Soft = true,
									Color = Theme.Colors.TextMuted,
									Text = scope:Computed(function(use): string
										local role = use(myRole)
										return if role then ROLE_LABELS[role] or role else ""
									end),
								}),
							},
						}),
						fieldLabel(scope, "Crew experience", 3),
						UI.ProgressBar(scope, {
							Name = "Bar",
							Size = UDim2.new(1, 0, 0, 30),
							LayoutOrder = 4,
							Value = scope:Computed(function(use): number
								local view = use(crew)
								if not view then
									return 0
								elseif view.Level >= CrewConfig.MaxLevel then
									return 1
								end
								return view.XP / expRequired(view)
							end),
							Text = scope:Computed(function(use): string
								local view = use(crew)
								if not view then
									return ""
								elseif view.Level >= CrewConfig.MaxLevel then
									return "MAX"
								end
								return `{Bind.formatNumber(view.XP)} / {Bind.formatNumber(expRequired(view))}`
							end),
						}),
					},
				}),
			},
		})

		-- Players tab -------------------------------------------------------------------
		local function askConfirmation(text: string, run: () -> ())
			confirmation:set({ Text = text, Run = run })
		end

		local function onKick()
			local member = Fusion.peek(selected)
			if not member then
				return
			end
			if member.UserId ~= localPlayer.UserId then
				askConfirmation(`Kick {member.Name} from the crew?`, function()
					CrewService.Kick:Fire(member.UserId)
				end)
			elseif Fusion.peek(isOwner) then
				askConfirmation("Disband the crew? This cannot be undone.", function()
					CrewService.Disband:Fire()
				end)
			else
				askConfirmation("Leave the crew?", function()
					CrewService.Leave:Fire()
				end)
			end
		end

		local function sendInvite()
			local typed = string.gsub(Fusion.peek(inviteName), "%s", "")
			if typed ~= "" then
				CrewService.Invite:Fire(typed)
				inviteName:set("")
			end
		end

		local actionSize = UDim2.new(1, 0, 0, 44)
		local playersPage = scope:New("Frame")({
			Name = "Players",
			Position = pagePosition,
			Size = pageSize,
			BackgroundTransparency = 1,
			Visible = pageVisible("Players"),
			[Fusion.Children] = {
				UI.Label(scope, {
					Name = "MembersNumber",
					Text = scope:Computed(function(use): string
						local view = use(crew)
						return if view then `Members  {#view.Members}/{view.MemberLimit + 1}` else ""
					end),
					Variant = "BodyBold",
					Color = Theme.Colors.Accent,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -(SIDE_WIDTH + Theme.Space.M), 0, 24),
				}),
				UI.Scroll(scope, {
					Name = "List",
					Position = UDim2.fromOffset(0, 24 + Theme.Space.S),
					Size = UDim2.new(1, -(SIDE_WIDTH + Theme.Space.M), 1, -(24 + Theme.Space.S)),
					Gap = Theme.Space.XS,
					Children = scope:ForValues(members, function(_use, rowScope: any, member: Member)
						return UI.Button(rowScope, {
							Name = member.Name,
							Variant = "Secondary",
							LayoutOrder = ROLE_ORDER[member.Role] or 2,
							Size = UDim2.new(1, 0, 0, MEMBER_HEIGHT),
							Selected = rowScope:Computed(function(use): boolean
								local picked = use(selected)
								return picked ~= nil and picked.UserId == member.UserId
							end),
							OnClick = function()
								selected:set(member)
								confirmation:set(nil)
							end,
							Children = {
								UI.Label(rowScope, {
									Name = "PlayerName",
									Text = member.Name,
									Variant = "BodyBold",
									TextXAlignment = Enum.TextXAlignment.Left,
									TextTruncate = Enum.TextTruncate.AtEnd,
									Position = UDim2.fromOffset(Theme.Space.M, 0),
									Size = UDim2.new(1, -150, 1, 0),
								}),
								UI.Label(rowScope, {
									Name = "RoleName",
									Text = ROLE_LABELS[member.Role] or member.Role,
									Variant = "Small",
									Color = ROLE_COLORS[member.Role] or Theme.Colors.TextMuted,
									TextXAlignment = Enum.TextXAlignment.Right,
									AnchorPoint = Vector2.new(1, 0),
									Position = UDim2.new(1, -Theme.Space.M, 0, 0),
									Size = UDim2.new(0, 120, 1, 0),
								}),
							},
						})
					end),
				}),

				UI.Panel(scope, {
					Name = "Selected",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, SIDE_WIDTH, 1, -(FIELD_HEIGHT * 2 + Theme.Space.S + Theme.Space.M)),
					Padding = Theme.Space.M,
					Children = {
						UI.Label(scope, {
							Name = "PlayerName",
							Text = scope:Computed(function(use): string
								local member = use(selected)
								return if member then member.Name else "Pick a member"
							end),
							Variant = "Heading",
							Color = scope:Computed(function(use): Color3
								return if use(selected) then Theme.Colors.Text else Theme.Colors.TextDim
							end),
							Scaled = true,
							Size = UDim2.new(1, 0, 0, 30),
						}),
						UI.Label(scope, {
							Name = "Role",
							Text = scope:Computed(function(use): string
								local member = use(selected)
								return if member then ROLE_LABELS[member.Role] or member.Role else ""
							end),
							Variant = "Small",
							Position = UDim2.fromOffset(0, 32),
							Size = UDim2.new(1, 0, 0, 20),
						}),

						UI.Stack(scope, {
							Name = "Actions",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 1, -64),
							Gap = Theme.Space.S,
							VerticalAlignment = Enum.VerticalAlignment.Bottom,
							Visible = notConfirming,
							Children = {
								UI.Button(scope, {
									Name = "Promote",
									Text = "Promote",
									Variant = "Success",
									Size = actionSize,
									LayoutOrder = 1,
									Visible = scope:Computed(function(use): boolean
										local member = use(selected)
										return use(isOwner) and member ~= nil and member.Role == "Member"
									end),
									OnClick = function()
										local member = Fusion.peek(selected)
										if member then
											CrewService.Promote:Fire(member.UserId)
										end
									end,
								}),
								UI.Button(scope, {
									Name = "Demote",
									Text = "Demote",
									Variant = "Secondary",
									Size = actionSize,
									LayoutOrder = 2,
									Visible = scope:Computed(function(use): boolean
										local member = use(selected)
										return use(isOwner) and member ~= nil and member.Role == "CoOwner"
									end),
									OnClick = function()
										CrewService.Demote:Fire()
									end,
								}),
								UI.Button(scope, {
									Name = "Kick",
									Text = scope:Computed(function(use): string
										if not use(selfSelected) then
											return "Kick"
										end
										return if use(isOwner) then "Disband" else "Leave"
									end),
									Variant = "Danger",
									Size = actionSize,
									LayoutOrder = 3,
									Visible = scope:Computed(function(use): boolean
										return use(selected) ~= nil and (use(isOwner) or use(selfSelected))
									end),
									OnClick = onKick,
								}),
							},
						}),

						scope:New("Frame")({
							Name = "Confirm",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 1, -64),
							BackgroundTransparency = 1,
							Visible = confirming,
							[Fusion.Children] = {
								UI.Label(scope, {
									Text = scope:Computed(function(use): string
										local pending = use(confirmation)
										return if pending then pending.Text else ""
									end),
									Variant = "Muted",
									Wrapped = true,
									Size = UDim2.new(1, 0, 1, -(44 + Theme.Space.S)),
								}),
								UI.Button(scope, {
									Name = "No",
									Text = "No",
									Variant = "Secondary",
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(0.5, -Theme.Space.XS, 0, 44),
									OnClick = function()
										confirmation:set(nil)
									end,
								}),
								UI.Button(scope, {
									Name = "Yes",
									Text = "Yes",
									Variant = "Danger",
									AnchorPoint = Vector2.new(1, 1),
									Position = UDim2.fromScale(1, 1),
									Size = UDim2.new(0.5, -Theme.Space.XS, 0, 44),
									OnClick = function()
										local pending = Fusion.peek(confirmation)
										confirmation:set(nil)
										if pending then
											pending.Run()
										end
									end,
								}),
							},
						}),
					},
				}),

				scope:New("Frame")({
					Name = "InviteRow",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(1, 1),
					Size = UDim2.fromOffset(SIDE_WIDTH, FIELD_HEIGHT * 2 + Theme.Space.S),
					BackgroundTransparency = 1,
					Visible = canInvite,
					[Fusion.Children] = {
						UI.TextInput(scope, {
							Name = "PlayerTextBox",
							Text = inviteName,
							Placeholder = "Player Name",
							Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
							OnSubmit = sendInvite,
						}),
						UI.Button(scope, {
							Name = "Invite",
							Text = "Invite",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
							OnClick = sendInvite,
						}),
					},
				}),
			},
		})

		-- Upgrades tab ------------------------------------------------------------------
		local function upgradeRow(order: number, name: string, text: any, price: any, visible: any, onClick: () -> ()): Frame
			return UI.Panel(scope, {
				Name = name,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 68),
				Padding = Theme.Space.M,
				Visible = visible,
				Children = {
					UI.Label(scope, {
						Text = text,
						Variant = "BodyBold",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, -200, 1, 0),
					}),
					priceButton(scope, {
						Name = "Promote",
						Text = price,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(180, 44),
						Disabled = sent,
						OnClick = onClick,
					}),
				},
			})
		end

		local function openEditor(value: Editor)
			editorText:set("")
			editor:set(value)
		end

		local upgradesPage = scope:New("Frame")({
			Name = "Upgrades",
			Position = pagePosition,
			Size = pageSize,
			BackgroundTransparency = 1,
			Visible = pageVisible("Upgrades"),
			[Fusion.Children] = {
				UI.Stack(scope, {
					Name = "Rows",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Gap = Theme.Space.S,
					Children = {
						UI.Label(scope, {
							Name = "OwnerOnly",
							Text = "Only the crew owner can buy upgrades.",
							Variant = "Muted",
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, 32),
							LayoutOrder = 0,
							Visible = scope:Computed(function(use): boolean
								return not use(isOwner)
							end),
						}),
						upgradeRow(
							1,
							"UpgradeCapacity",
							scope:Computed(function(use): string
								local view = use(crew)
								local limit = if view then view.MemberLimit else 0
								return `Crew Member Slots {limit} -> {limit + 1}`
							end),
							scope:Computed(function(use): string
								local view = use(crew)
								return Bind.formatNumber(CrewConfig.GetCapacityPrice(if view then view.Level else 0))
							end),
							scope:Computed(function(use): boolean
								local view = use(crew)
								return view ~= nil
									and use(isOwner)
									and CrewConfig.CanUpgradeCapacity(view.Level, view.MemberLimit)
							end),
							function()
								markSent()
								CrewService.UpgradeCapacity:Fire()
							end
						),
						upgradeRow(
							2,
							"ChangeLogo",
							"Change Crew Logo",
							Bind.formatNumber(CrewConfig.LogoPrice),
							isOwner,
							function()
								openEditor({
									Title = "New crew logo",
									Placeholder = "Insert your image ID",
									Send = function(text: string)
										CrewService.ChangeLogo:Fire(text)
									end,
								})
							end
						),
						upgradeRow(
							3,
							"ChangeName",
							"Change Crew Name",
							Bind.formatNumber(CrewConfig.RenamePrice),
							isOwner,
							function()
								openEditor({
									Title = "New crew name",
									Placeholder = "Insert your crew name",
									Send = function(text: string)
										CrewService.Rename:Fire(text)
									end,
								})
							end
						),
					},
				}),

				UI.Panel(scope, {
					Name = "Editor",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 112),
					Color = Theme.Colors.Raised,
					Stroke = Theme.Colors.BorderStrong,
					Padding = Theme.Space.M,
					Visible = scope:Computed(function(use): boolean
						return use(editor) ~= nil and use(isOwner)
					end),
					Children = {
						UI.Label(scope, {
							Text = scope:Computed(function(use): string
								local current = use(editor)
								return if current then current.Title else ""
							end),
							Variant = "BodyBold",
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, 24),
						}),
						UI.TextInput(scope, {
							Name = "TextBox",
							Text = editorText,
							Placeholder = scope:Computed(function(use): string
								local current = use(editor)
								return if current then current.Placeholder else ""
							end),
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, -(160 * 2 + Theme.Space.S * 2), 0, FIELD_HEIGHT),
						}),
						UI.Button(scope, {
							Name = "Decline",
							Text = "Cancel",
							Variant = "Secondary",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.new(1, -(160 + Theme.Space.S), 1, 0),
							Size = UDim2.fromOffset(160, FIELD_HEIGHT),
							OnClick = function()
								editor:set(nil)
							end,
						}),
						UI.Button(scope, {
							Name = "Confirm",
							Text = "Confirm",
							Variant = "Success",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.fromScale(1, 1),
							Size = UDim2.fromOffset(160, FIELD_HEIGHT),
							OnClick = function()
								local current = Fusion.peek(editor)
								editor:set(nil)
								if current then
									markSent()
									current.Send(Fusion.peek(editorText))
								end
							end,
						}),
					},
				}),
			},
		})

		return UI.Screen(scope, {
			Name = "CrewGui",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Crew Menu",
					Size = UDim2.fromOffset(900, 620),
					OnClose = context.Close,
					Children = {
						createView,
						scope:New("Frame")({
							Name = "InCrew",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Visible = hasCrew,
							[Fusion.Children] = {
								UI.Tabs(scope, {
									Tabs = TABS :: any,
									Selected = tab,
									TabSize = UDim2.fromOffset(160, TAB_HEIGHT),
									OnSelect = function()
										editor:set(nil)
										confirmation:set(nil)
									end,
								}),
								menuPage,
								playersPage,
								upgradesPage,
							},
						}),
					},
				}),
			},
		})
	end,
}
