--!strict
--[[
	Crew menu (legacy CrewGui / CrewsHandler), tab I of the side menu: the old burnt sheet
	in the middle of the screen, "Crew Menu" across the top. One window and one grid for
	every state: a band across the top, and under it the content on the same two edges.

	Without a crew: the band says so; under it the create form at the left (image id, crew
	name, Create and its price in Gems) and the invitation at the right ("Do you want to
	join the X crew?" with Confirm / Decline while someone invited you).
	In a crew: the band holds the crew's name, its level and the experience bar (the count
	written in it); under it the three plank buttons in a column at the left and the page
	of the picked one filling the rest.
	  Menu      the logo (when the crew has one) beside the crew's facts, and Leave /
	            Disband at the bottom: the legacy screen had no way to leave a crew.
	  Players   member list (name and role); pick a name, then promote / demote / kick
	            (owner) at the right, and under them the box to invite a player.
	            Picking yourself turns Kick into "Leave" (or "Disband" for the owner).
	  Upgrades  member slots, logo, name (owner, paid in Gems)

	Everything shown comes from the crew view the server sends (CrewController); the
	buttons only send intents through CrewService. The legacy script bumped its own copy of
	the member limit and reconnected the invite buttons on every invite: state does that here.

	The old text boxes held their prompt as text ("Insert your crew name"), which the old
	script sent as if it had been typed: they are placeholders here. The old screen had no
	close button; the window's X (and the gamepad's B) closes it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local CrewConfig = require(ReplicatedStorage.Shared.Configs.CrewConfig)
local GemPrice = require(ReplicatedStorage.Client.UI.Legacy.Components.GemPrice)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>
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

local ROLE_LABELS: { [string]: string } = { Owner = "Owner", CoOwner = "Co-Owner", Member = "Member" }
local ROLE_ORDER: { [string]: number } = { Owner = 0, CoOwner = 1, Member = 2 }
local TABS: { { Name: string, Text: string } } = {
	{ Name = "MenuButton", Text = "Menu" },
	{ Name = "Players", Text = "Players" },
	{ Name = "Upgrades", Text = "Upgrades" },
}

local DISPLAY_ORDER = 10
-- A button that sent a request does nothing this long (the answer comes as a new crew view).
local SENT_SECONDS = 1

-- The colours the old screen gave its planks, now worn by the text they stood for: the
-- crew's name, its level (and the experience bar), a role.
local NAME_COLOR = Kit.Colors.Gold
local LEVEL_COLOR = Color3.fromRGB(64, 255, 64)
local ROLE_COLORS: { [string]: Color3 } = {
	Owner = Kit.Colors.Gold,
	CoOwner = Color3.fromRGB(0, 255, 234),
	Member = Kit.Colors.Text,
}

local GAP = Kit.Space.M
local PAD = Kit.Space.M

-- The window's body is 992 x 556 (the sheet less its padding and its title).
local WINDOW_SIZE = Vector2.new(1040, 660)
local BAND_HEIGHT = 64
local CONTENT_TOP = BAND_HEIGHT + GAP
local BAND_NAME_WIDTH = 380
local BAND_LEVEL_WIDTH = 150
local BAND_BAR_HEIGHT = 30

local TAB_SIZE = Vector2.new(190, 52)
local PAGE_LEFT = TAB_SIZE.X + GAP

-- Menu page: six facts as tall as the logo, a line, the action row.
local FACT_HEIGHT = 56
local FACT_COUNT = 6
local LOGO_SIDE = FACT_COUNT * FACT_HEIGHT + (FACT_COUNT - 1) * Kit.Space.S
local ACTION_ROW_HEIGHT = 48
local LEAVE_WIDTH = 260

-- Players page.
local SIDE_WIDTH = 260
local LIST_HEADER_HEIGHT = 32
local ROW_HEIGHT = 48
local ROLE_WIDTH = 150
-- Kept free at the right of the rows for the scroll bar.
local SCROLL_GUTTER = 10
local ACTION_HEIGHT = 44
local CAPTION_HEIGHT = 24
local INVITE_HEIGHT = 2 * PAD + CAPTION_HEIGHT + 2 * ACTION_HEIGHT + 2 * Kit.Space.S

-- Upgrades page.
local UPGRADE_HEIGHT = 76
local UPGRADE_BUTTON_SIZE = Vector2.new(180, 48)
local UPGRADE_PRICE_WIDTH = 150

-- Without a crew.
local FORM_WIDTH = 590
local BOX_HEIGHT = 48
local TITLE_HEIGHT = 36
local CREATE_BUTTON_SIZE = UDim2.fromOffset(260, 56)
local ANSWER_HEIGHT = 52

local DIALOG_SIZE = Vector2.new(600, 300)
local DIALOG_BUTTON_SIZE = UDim2.fromOffset(220, 52)

local localPlayer = Players.LocalPlayer

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local CrewService = Knit.GetService("CrewService")
		local CrewController = Knit.GetController("CrewController")

		local crew: Fusion.Value<Crew?> = scope:Value(CrewController:GetCrew() :: Crew?)
		local invite = scope:Value(CrewController:GetInvite())
		local tab = scope:Value(TABS[1].Name)
		local selected: Fusion.Value<Member?> = scope:Value(nil :: Member?)
		local confirmation: Fusion.Value<Confirmation?> = scope:Value(nil :: Confirmation?)
		-- Which upgrade is asking for text: "Logo" | "Name" | nil.
		local editing: Fusion.Value<string?> = scope:Value(nil :: string?)

		-- True for SENT_SECONDS after a paid request: the buttons that send one wait.
		local sent = false
		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)
		local function markSent()
			sent = true
			task.delay(SENT_SECONDS, function()
				if mounted then
					sent = false
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
		local selfSelected = scope:Computed(function(use): boolean
			local member = use(selected)
			return member ~= nil and member.UserId == localPlayer.UserId
		end)
		local members = scope:Computed(function(use): { Member }
			local view = use(crew)
			return if view then view.Members else {}
		end)
		local hasLogo = scope:Computed(function(use): boolean
			local view = use(crew)
			return view ~= nil and view.ImageId ~= "0" and view.ImageId ~= ""
		end)
		local hasInvite = scope:Computed(function(use): boolean
			return use(invite) ~= nil and use(crew) == nil
		end)

		local function expRequired(view: Crew): number
			return math.ceil(CrewConfig.GetExpRequired(view.Level))
		end

		-- Leaving is the owner's disbanding.
		local function askLeave()
			if Fusion.peek(isOwner) then
				confirmation:set({
					Text = "Disband the crew? This cannot be undone.",
					Run = function()
						CrewService.Disband:Fire()
					end,
				})
			else
				confirmation:set({
					Text = "Leave the crew?",
					Run = function()
						CrewService.Leave:Fire()
					end,
				})
			end
		end

		-- Building blocks ---------------------------------------------------------------

		-- A sheet laid over the content to ask something: a line of text or a text box,
		-- and two buttons under it. The shade behind it takes the clicks meant for what
		-- it covers.
		local function dialog(props: {
			Name: string,
			Visible: UsedAs<boolean>,
			Content: Instance,
			AcceptText: string,
			DeclineText: string,
			OnAccept: () -> (),
			OnDecline: () -> (),
		}): Instance
			local buttons = DIALOG_BUTTON_SIZE.Y.Offset
			return scope:New("Frame")({
				Name = props.Name,
				Active = true,
				BackgroundColor3 = Kit.Colors.Sunken,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 10,
				Visible = props.Visible,
				[Fusion.Children] = {
					Kit.Panel(scope, {
						Name = "Sheet",
						Image = Kit.Images.Sheet,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(DIALOG_SIZE.X, DIALOG_SIZE.Y),
						Padding = Kit.Space.XL,
						Children = {
							scope:New("Frame")({
								Name = "Content",
								BackgroundTransparency = 1,
								Size = UDim2.new(1, 0, 1, -(buttons + Kit.Space.L)),
								[Fusion.Children] = props.Content,
							}),
							Kit.Stack(scope, {
								Name = "Buttons",
								Direction = "Horizontal",
								Gap = Kit.Space.XL,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, buttons),
								Children = {
									Kit.Button(scope, {
										Name = "Accept",
										Text = props.AcceptText,
										Variant = "Green",
										Size = DIALOG_BUTTON_SIZE,
										LayoutOrder = 1,
										OnClick = props.OnAccept,
									}),
									Kit.Button(scope, {
										Name = "Decline",
										Text = props.DeclineText,
										Variant = "Red",
										Size = DIALOG_BUTTON_SIZE,
										LayoutOrder = 2,
										OnClick = props.OnDecline,
									}),
								},
							}),
						},
					}),
				},
			})
		end

		-- The question of a dialog, in its dark box.
		local function question(text: UsedAs<string>): Instance
			return Kit.Well(scope, {
				Name = "Question",
				Transparency = 0.4,
				Size = UDim2.fromScale(1, 1),
				Padding = Kit.Space.M,
				Children = {
					Kit.Label(scope, {
						Text = text,
						TextSize = Kit.TextSize.Heading,
						Fit = true,
						Size = UDim2.fromScale(1, 1),
					}),
				},
			})
		end

		-- A small heading over a field or a list, at the left.
		local function caption(text: UsedAs<string>, order: number?, height: number?): Instance
			return Kit.Label(scope, {
				Name = "Caption",
				Text = text,
				TextSize = Kit.TextSize.Small,
				TextXAlignment = Enum.TextXAlignment.Left,
				Fit = true,
				Size = UDim2.new(1, 0, 0, height or CAPTION_HEIGHT),
				LayoutOrder = order,
			})
		end

		-- A paragraph of help, in the regular weight.
		local function note(props: Kit.Layout & { Text: UsedAs<string> }): Instance
			return Kit.Label(
				scope,
				Kit.place(props, {
					Name = "Note",
					Text = props.Text,
					TextSize = Kit.TextSize.Small,
					Bold = false,
					Color = Kit.Colors.TextDim,
					Wrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}) :: any
			)
		end

		-- The band across the top of both states.
		local function band(name: string, children: { any }): Instance
			return Kit.Well(scope, {
				Name = name,
				Size = UDim2.new(1, 0, 0, BAND_HEIGHT),
				Padding = PAD,
				Children = children,
			})
		end

		local function page(name: string, children: { any }): Instance
			return scope:New("Frame")({
				Name = name,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = scope:Computed(function(use): boolean
					return use(tab) == name
				end),
				[Fusion.Children] = children,
			})
		end

		local function openTab(name: string)
			tab:set(name)
			editing:set(nil)
			confirmation:set(nil)
		end

		-- Without a crew ----------------------------------------------------------------

		local imageBox = Kit.TextInput(scope, {
			Name = "GroupID",
			Placeholder = "Insert your image ID",
			Size = UDim2.new(1, 0, 0, BOX_HEIGHT),
			LayoutOrder = 3,
		})
		local nameBox: TextBox
		nameBox = Kit.TextInput(scope, {
			Name = "CrewName",
			Placeholder = "Insert your crew name",
			Size = UDim2.new(1, 0, 0, BOX_HEIGHT),
			LayoutOrder = 5,
			-- Only convenience: the server checks the name whatever is sent.
			OnChanged = function(text: string)
				local length = utf8.len(text)
				if length and length > CrewConfig.NameMaxLength then
					nameBox.Text =
						string.sub(text, 1, (utf8.offset(text, CrewConfig.NameMaxLength + 1) or (#text + 1)) - 1)
				end
			end,
		})

		local answerTop = TITLE_HEIGHT + Kit.Space.S

		local createFrame = scope:New("Frame")({
			Name = "CreateFrame",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = scope:Computed(function(use): boolean
				return use(crew) == nil
			end),
			[Fusion.Children] = {
				band("Band", {
					Kit.Label(scope, {
						Name = "Title",
						Text = "You are not in a crew",
						TextSize = Kit.TextSize.Title,
						Fit = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(0.5, -GAP / 2, 1, 0),
					}),
					Kit.Label(scope, {
						Name = "Hint",
						Text = "Create your own, or ask a crew to invite you.",
						TextSize = Kit.TextSize.Small,
						Color = Kit.Colors.TextDim,
						Fit = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.5, -GAP / 2, 1, 0),
					}),
				}),

				Kit.Well(scope, {
					Name = "Form",
					Position = UDim2.fromOffset(0, CONTENT_TOP),
					Size = UDim2.new(0, FORM_WIDTH, 1, -CONTENT_TOP),
					Padding = Kit.Space.L,
					Children = {
						Kit.Stack(scope, {
							Name = "Rows",
							Gap = Kit.Space.S,
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Children = {
								Kit.Label(scope, {
									Name = "Title",
									Text = "Create a Crew",
									TextSize = Kit.TextSize.Heading,
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
									LayoutOrder = 1,
								}),
								caption("Image ID", 2),
								imageBox,
								caption("Crew Name", 4),
								nameBox,
								note({
									Text = `The image ID is the number of a Roblox image. The name can have up to {CrewConfig.NameMaxLength} characters. The owner can change both later, in Upgrades.`,
									Size = UDim2.new(1, 0, 0, 3 * CAPTION_HEIGHT),
									LayoutOrder = 6,
								}),
							},
						}),
						Kit.Stack(scope, {
							Name = "Create",
							Direction = "Horizontal",
							Gap = Kit.Space.L,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Children = {
								Kit.Button(scope, {
									Name = "CreateButton",
									Text = "Create",
									Variant = "Green",
									TextSize = Kit.TextSize.Heading,
									Size = CREATE_BUTTON_SIZE,
									LayoutOrder = 1,
									OnClick = function()
										if not sent then
											markSent()
											CrewService.Create:Fire(nameBox.Text, imageBox.Text)
										end
									end,
								}),
								GemPrice.new(scope, {
									Text = Bind.formatNumber(CrewConfig.CreatePrice),
									LayoutOrder = 2,
								}),
							},
						}),
					},
				}),

				Kit.Well(scope, {
					Name = "ConfirmFrame",
					Position = UDim2.fromOffset(FORM_WIDTH + GAP, CONTENT_TOP),
					Size = UDim2.new(1, -(FORM_WIDTH + GAP), 1, -CONTENT_TOP),
					Padding = Kit.Space.L,
					Children = {
						Kit.Label(scope, {
							Name = "Title",
							Text = "Invitation",
							TextSize = Kit.TextSize.Heading,
							TextXAlignment = Enum.TextXAlignment.Left,
							Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						}),
						Kit.Well(scope, {
							Name = "Question",
							Transparency = 0.6,
							Position = UDim2.fromOffset(0, answerTop),
							-- Without an invitation there are no buttons to leave room for.
							Size = scope:Computed(function(use): UDim2
								return if use(hasInvite)
									then UDim2.new(1, 0, 1, -(answerTop + ANSWER_HEIGHT + GAP))
									else UDim2.new(1, 0, 1, -answerTop)
							end),
							Padding = Kit.Space.L,
							Children = {
								Kit.Label(scope, {
									Text = scope:Computed(function(use): string
										local pending = use(invite)
										return if pending
											then `Do you want to join the {pending.CrewName} crew?`
											else "No invitation yet. When a crew invites you, it shows up here."
									end),
									Color = scope:Computed(function(use): Color3
										return if use(invite) then Kit.Colors.Text else Kit.Colors.TextDim
									end),
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),
						Kit.Button(scope, {
							Name = "Confirm",
							Text = "Confirm",
							Variant = "Green",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(0.5, -GAP / 2, 0, ANSWER_HEIGHT),
							Visible = hasInvite,
							OnClick = function()
								CrewController:AnswerInvite(true)
							end,
						}),
						Kit.Button(scope, {
							Name = "Decline",
							Text = "Decline",
							Variant = "Red",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.fromScale(1, 1),
							Size = UDim2.new(0.5, -GAP / 2, 0, ANSWER_HEIGHT),
							Visible = hasInvite,
							OnClick = function()
								CrewController:AnswerInvite(false)
							end,
						}),
					},
				}),
			},
		})

		-- The crew's band ---------------------------------------------------------------

		local crewBand = band("Band", {
			Kit.Stack(scope, {
				Name = "Row",
				Direction = "Horizontal",
				Gap = GAP,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Children = {
					Kit.Label(scope, {
						Name = "CrewName",
						Color = NAME_COLOR,
						TextSize = Kit.TextSize.Title,
						Fit = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(0, BAND_NAME_WIDTH, 1, 0),
						LayoutOrder = 1,
						Text = scope:Computed(function(use): string
							local view = use(crew)
							return if view then view.Name else ""
						end),
					}),
					Kit.Label(scope, {
						Name = "CrewLvL",
						Color = LEVEL_COLOR,
						TextSize = Kit.TextSize.Heading,
						Fit = true,
						Size = UDim2.new(0, BAND_LEVEL_WIDTH, 1, 0),
						LayoutOrder = 2,
						Text = scope:Computed(function(use): string
							local view = use(crew)
							return `Level: {if view then view.Level else 0}`
						end),
					}),
					Kit.Bar(scope, {
						Name = "Bar",
						Color = LEVEL_COLOR,
						Size = UDim2.new(1, -(BAND_NAME_WIDTH + BAND_LEVEL_WIDTH + 2 * GAP), 0, BAND_BAR_HEIGHT),
						LayoutOrder = 3,
						Value = scope:Computed(function(use): number
							local view = use(crew)
							if view and view.Level >= CrewConfig.MaxLevel then
								return 1
							end
							-- Legacy bar: a tenth is always filled, the rest follows the experience.
							local progress = if view then math.clamp(view.XP / expRequired(view) * 0.9, 0, 0.9) else 0
							return 0.1 + progress
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
		})

		-- Tabs --------------------------------------------------------------------------

		local tabButtons: { Instance } = {}
		for index, entry in TABS do
			table.insert(
				tabButtons,
				Kit.Button(scope, {
					Name = entry.Name,
					Text = entry.Text,
					Size = UDim2.fromOffset(TAB_SIZE.X, TAB_SIZE.Y),
					LayoutOrder = index,
					Selected = scope:Computed(function(use): boolean
						return use(tab) == entry.Name
					end),
					OnClick = function()
						openTab(entry.Name)
					end,
				})
			)
		end

		-- Menu tab ----------------------------------------------------------------------

		-- A line of the crew's facts: what it is at the left, its value at the right.
		local function fact(order: number, label: string, value: UsedAs<string>, color: UsedAs<Color3>?): Instance
			return Kit.Well(scope, {
				Name = "Fact",
				Transparency = 0.6,
				Size = UDim2.new(1, 0, 0, FACT_HEIGHT),
				Padding = PAD,
				LayoutOrder = order,
				Children = {
					Kit.Label(scope, {
						Name = "Label",
						Text = label,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.fromScale(0.4, 1),
					}),
					Kit.Label(scope, {
						Name = "Value",
						Text = value,
						Color = color,
						Fit = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.6, 1),
					}),
				},
			})
		end

		local menuPage = page(TABS[1].Name, {
			Kit.Well(scope, {
				Name = "Logo",
				Transparency = 0.6,
				Size = UDim2.fromOffset(LOGO_SIDE, LOGO_SIDE),
				-- A crew without a logo gives its place to the facts.
				Visible = hasLogo,
				Children = {
					Kit.Image(scope, {
						Name = "CrewImage",
						Size = UDim2.fromScale(1, 1),
						Image = scope:Computed(function(use): string
							local view = use(crew)
							return if view and view.ImageId ~= "0" then `rbxassetid://{view.ImageId}` else ""
						end),
					}),
				},
			}),
			Kit.Stack(scope, {
				Name = "Facts",
				Gap = Kit.Space.S,
				Position = scope:Computed(function(use): UDim2
					return if use(hasLogo) then UDim2.fromOffset(LOGO_SIDE + GAP, 0) else UDim2.new()
				end),
				Size = scope:Computed(function(use): UDim2
					return if use(hasLogo)
						then UDim2.new(1, -(LOGO_SIDE + GAP), 0, LOGO_SIDE)
						else UDim2.new(1, 0, 0, LOGO_SIDE)
				end),
				Children = {
					fact(
						1,
						"Owner",
						scope:Computed(function(use): string
							for _, member in use(members) do
								if member.Role == "Owner" then
									return member.Name
								end
							end
							return "-"
						end),
						ROLE_COLORS.Owner
					),
					fact(
						2,
						"Your Role",
						scope:Computed(function(use): string
							local role = use(myRole)
							return if role then ROLE_LABELS[role] or role else "-"
						end),
						scope:Computed(function(use): Color3
							local role = use(myRole)
							return (if role then ROLE_COLORS[role] else nil) or Kit.Colors.Text
						end)
					),
					fact(
						3,
						"Members",
						scope:Computed(function(use): string
							local view = use(crew)
							-- The owner does not use a member slot.
							return if view then `{#view.Members} / {view.MemberLimit + 1}` else "-"
						end)
					),
					fact(
						4,
						"Co-Owners",
						scope:Computed(function(use): string
							local count = 0
							for _, member in use(members) do
								if member.Role == "CoOwner" then
									count += 1
								end
							end
							return tostring(count)
						end),
						ROLE_COLORS.CoOwner
					),
					fact(
						5,
						"Level",
						scope:Computed(function(use): string
							local view = use(crew)
							return `{if view then view.Level else 0} / {CrewConfig.MaxLevel}`
						end),
						LEVEL_COLOR
					),
					fact(
						6,
						"Next Level",
						scope:Computed(function(use): string
							local view = use(crew)
							if not view then
								return "-"
							elseif view.Level >= CrewConfig.MaxLevel then
								return "MAX"
							end
							return `{Bind.formatNumber(math.max(expRequired(view) - view.XP, 0))} exp`
						end)
					),
				},
			}),

			Kit.Divider(scope, {
				-- Halfway between the facts and the action row.
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, (LOGO_SIDE - ACTION_ROW_HEIGHT) / 2),
			}),
			scope:New("Frame")({
				Name = "Actions",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, ACTION_ROW_HEIGHT),
				[Fusion.Children] = {
					note({
						Text = scope:Computed(function(use): string
							return if use(isOwner)
								then "Disbanding removes the crew for every member. This cannot be undone."
								else "After leaving, you need a new invitation to come back."
						end),
						Size = UDim2.new(1, -(LEAVE_WIDTH + GAP), 1, 0),
					}),
					Kit.Button(scope, {
						Name = "Leave",
						Variant = "Red",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0, LEAVE_WIDTH, 1, 0),
						Text = scope:Computed(function(use): string
							return if use(isOwner) then "Disband Crew" else "Leave Crew"
						end),
						OnClick = askLeave,
					}),
				},
			}),
		})

		-- Players tab -------------------------------------------------------------------

		local listRight = SIDE_WIDTH + GAP
		local listTop = LIST_HEADER_HEIGHT + Kit.Space.S

		local inviteBox = Kit.TextInput(scope, {
			Name = "PlayerTextBox",
			Placeholder = "Player Name",
			Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
			LayoutOrder = 2,
		})
		local function sendInvite()
			local typed = string.gsub(inviteBox.Text, "%s", "")
			if typed ~= "" then
				CrewService.Invite:Fire(typed)
				inviteBox.Text = ""
			end
		end
		table.insert(scope, inviteBox.FocusLost:Connect(function(enterPressed: boolean)
			if enterPressed then
				sendInvite()
			end
		end))

		local function kickOrLeave()
			local member = Fusion.peek(selected)
			if not member then
				return
			end

			if member.UserId ~= localPlayer.UserId then
				confirmation:set({
					Text = `Kick {member.Name} from the crew?`,
					Run = function()
						CrewService.Kick:Fire(member.UserId)
					end,
				})
			else
				askLeave()
			end
		end

		local actionSize = UDim2.new(1, 0, 0, ACTION_HEIGHT)
		local selectedTop = TITLE_HEIGHT + CAPTION_HEIGHT + Kit.Space.S

		local playersPage = page(TABS[2].Name, {
			scope:New("Frame")({
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -listRight, 0, LIST_HEADER_HEIGHT),
				[Fusion.Children] = {
					Kit.Label(scope, {
						Name = "MembersNumber",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, -(ROLE_WIDTH + SCROLL_GUTTER + Kit.Space.XS), 1, 0),
						Text = scope:Computed(function(use): string
							local view = use(crew)
							-- The owner does not use a member slot.
							return if view then `Members: {#view.Members}/{view.MemberLimit + 1}` else ""
						end),
					}),
					-- Over the column of the roles.
					Kit.Label(scope, {
						Name = "Role",
						Text = "Role",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -SCROLL_GUTTER, 0, 0),
						Size = UDim2.new(0, ROLE_WIDTH, 1, 0),
					}),
				},
			}),
			Kit.Scroll(scope, {
				Name = "Members",
				Background = false,
				Padding = 0,
				Gap = Kit.Space.XS,
				Position = UDim2.fromOffset(0, listTop),
				Size = UDim2.new(1, -listRight, 1, -listTop),
				Children = scope:ForValues(members, function(_use, rowScope: Scope, member: Member)
					return rowScope:New("Frame")({
						Name = member.Name,
						BackgroundTransparency = 1,
						LayoutOrder = ROLE_ORDER[member.Role] or 2,
						Size = UDim2.new(1, -SCROLL_GUTTER, 0, ROW_HEIGHT),
						[Fusion.Children] = {
							-- The picked member's name turns green.
							Kit.Button(rowScope, {
								Name = "PlayerName",
								Text = member.Name,
								Size = UDim2.new(1, -(ROLE_WIDTH + Kit.Space.XS), 1, 0),
								Selected = rowScope:Computed(function(use): boolean
									local picked = use(selected)
									return picked ~= nil and picked.UserId == member.UserId
								end),
								OnClick = function()
									selected:set(member)
									confirmation:set(nil)
								end,
							}),
							Kit.Well(rowScope, {
								Name = "RoleName",
								Transparency = 0.6,
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.fromScale(1, 0),
								Size = UDim2.new(0, ROLE_WIDTH, 1, 0),
								Children = {
									Kit.Label(rowScope, {
										Text = ROLE_LABELS[member.Role] or member.Role,
										Color = ROLE_COLORS[member.Role] or Kit.Colors.Text,
										Fit = true,
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.new(1, -2 * Kit.Space.S, 1, -2 * Kit.Space.S),
									}),
								},
							}),
						},
					})
				end),
			}),

			Kit.Well(scope, {
				Name = "Selected",
				Transparency = 0.6,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				-- Down to the invite box, or to the bottom for who cannot invite.
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(0, SIDE_WIDTH, 1, if use(canInvite) then -(INVITE_HEIGHT + GAP) else 0)
				end),
				Padding = PAD,
				Children = {
					Kit.Label(scope, {
						Name = "PlayerName",
						TextSize = Kit.TextSize.Heading,
						Fit = true,
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						Text = scope:Computed(function(use): string
							local member = use(selected)
							return if member then member.Name else "Pick a member"
						end),
						Color = scope:Computed(function(use): Color3
							return if use(selected) then Kit.Colors.Text else Kit.Colors.TextDim
						end),
					}),
					Kit.Label(scope, {
						Name = "RoleName",
						TextSize = Kit.TextSize.Small,
						Position = UDim2.fromOffset(0, TITLE_HEIGHT),
						Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
						Text = scope:Computed(function(use): string
							local member = use(selected)
							return if member then ROLE_LABELS[member.Role] or member.Role else ""
						end),
						Color = scope:Computed(function(use): Color3
							local member = use(selected)
							return (if member then ROLE_COLORS[member.Role] else nil) or Kit.Colors.Text
						end),
					}),
					-- Says why there is no button, when there is none.
					note({
						Position = UDim2.fromOffset(0, selectedTop),
						Size = UDim2.new(1, 0, 0, 3 * CAPTION_HEIGHT),
						Text = scope:Computed(function(use): string
							if use(selected) == nil then
								return "Click a name in the list to see what you can do."
							elseif not use(isOwner) and not use(selfSelected) then
								return "Only the crew owner can promote, demote or kick."
							end
							return ""
						end),
					}),
					Kit.Stack(scope, {
						Name = "Actions",
						Gap = Kit.Space.S,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						Children = {
							Kit.Button(scope, {
								Name = "Promote",
								Text = "Promote",
								Variant = "Green",
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
							Kit.Button(scope, {
								Name = "Demote",
								Text = "Demote",
								Variant = "Orange",
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
							Kit.Button(scope, {
								Name = "Kick",
								Variant = "Red",
								Size = actionSize,
								LayoutOrder = 3,
								Text = scope:Computed(function(use): string
									if not use(selfSelected) then
										return "Kick"
									end
									return if use(isOwner) then "Disband" else "Leave"
								end),
								Visible = scope:Computed(function(use): boolean
									return use(selected) ~= nil and (use(isOwner) or use(selfSelected))
								end),
								OnClick = kickOrLeave,
							}),
						},
					}),
				},
			}),

			Kit.Well(scope, {
				Name = "Invite",
				Transparency = 0.6,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(SIDE_WIDTH, INVITE_HEIGHT),
				Padding = PAD,
				Visible = canInvite,
				Children = {
					Kit.Stack(scope, {
						Name = "Rows",
						Gap = Kit.Space.S,
						Size = UDim2.fromScale(1, 1),
						Children = {
							caption("Invite a Player", 1),
							inviteBox,
							Kit.Button(scope, {
								Name = "Invite",
								Text = "Invite",
								Variant = "Green",
								Size = actionSize,
								LayoutOrder = 3,
								OnClick = sendInvite,
							}),
						},
					}),
				},
			}),
		})

		-- Upgrades tab ------------------------------------------------------------------

		local upgradeText = UDim2.new(1, -(UPGRADE_BUTTON_SIZE.X + UPGRADE_PRICE_WIDTH + 2 * GAP), 0.5, 0)

		-- A row of the list: what the upgrade is, then its price and its button, each in
		-- its column.
		local function upgradeRow(props: {
			Name: string,
			Text: UsedAs<string>,
			Detail: string?,
			Order: number,
			Visible: UsedAs<boolean>,
			Price: UsedAs<string>?,
			OnClick: (() -> ())?,
		}): Instance
			return Kit.Well(scope, {
				Name = props.Name,
				Transparency = 0.6,
				Size = UDim2.new(1, 0, 0, UPGRADE_HEIGHT),
				Padding = PAD,
				LayoutOrder = props.Order,
				Visible = props.Visible,
				Children = {
					Kit.Label(scope, {
						Name = "Text",
						Text = props.Text,
						Fit = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						-- Without a button the text has the whole row.
						Size = if props.OnClick then upgradeText else UDim2.fromScale(1, 1),
					}),
					if props.OnClick and props.Detail
						then Kit.Label(scope, {
							Name = "Detail",
							Text = props.Detail,
							TextSize = Kit.TextSize.Small,
							Bold = false,
							Color = Kit.Colors.TextDim,
							Fit = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							Position = UDim2.fromScale(0, 0.5),
							Size = upgradeText,
						})
						else nil,
					if props.OnClick
						then GemPrice.new(scope, {
							Text = props.Price or "",
							TextSize = Kit.TextSize.Body,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -(UPGRADE_BUTTON_SIZE.X + GAP), 0.5, 0),
						})
						else nil,
					if props.OnClick
						then Kit.Button(scope, {
							Name = "Promote",
							Text = "Upgrade",
							Variant = "Green",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(UPGRADE_BUTTON_SIZE.X, UPGRADE_BUTTON_SIZE.Y),
							OnClick = props.OnClick,
						})
						else nil,
				} :: { any },
			})
		end

		-- An upgrade that asks for a text first: its row, and the sheet with the box.
		local function textUpgrade(
			kind: string,
			rowName: string,
			dialogName: string,
			title: string,
			detail: string,
			order: number,
			price: number,
			placeholder: string,
			send: (string) -> ()
		): (Instance, Instance)
			local box = Kit.TextInput(scope, {
				Name = "TextBox",
				Placeholder = placeholder,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, BOX_HEIGHT),
			})

			local row = upgradeRow({
				Name = rowName,
				Text = title,
				Detail = detail,
				Order = order,
				Visible = isOwner,
				Price = Bind.formatNumber(price),
				OnClick = function()
					if sent then
						return
					end
					-- Every opening starts from an empty box.
					box.Text = ""
					editing:set(kind)
				end,
			})

			local sheet = dialog({
				Name = dialogName,
				Visible = scope:Computed(function(use): boolean
					return use(editing) == kind and use(isOwner)
				end),
				Content = scope:New("Frame")({
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					[Fusion.Children] = {
						Kit.Label(scope, {
							Name = "Title",
							Text = title,
							TextSize = Kit.TextSize.Title,
							Fit = true,
							Size = UDim2.new(1, 0, 1, -(BOX_HEIGHT + Kit.Space.M)),
						}),
						box,
					},
				}),
				AcceptText = "Confirm",
				DeclineText = "Decline",
				OnAccept = function()
					editing:set(nil)
					markSent()
					send(box.Text)
				end,
				OnDecline = function()
					editing:set(nil)
				end,
			})
			return row, sheet
		end

		local logoRow, logoSheet = textUpgrade(
			"Logo",
			"ChangeLogo",
			"ChangeLogoTemplate",
			"Change Crew Logo",
			"A new image for the crew, by its image ID.",
			2,
			CrewConfig.LogoPrice,
			"Insert your image ID",
			function(text: string)
				CrewService.ChangeLogo:Fire(text)
			end
		)
		local nameRow, nameSheet = textUpgrade(
			"Name",
			"ChangeName",
			"ChangeNameTemplate",
			"Change Crew Name",
			"A new name for the crew.",
			3,
			CrewConfig.RenamePrice,
			"Insert your crew name",
			function(text: string)
				CrewService.Rename:Fire(text)
			end
		)

		local upgradesPage = page(TABS[3].Name, {
			Kit.Scroll(scope, {
				Name = "List",
				Background = false,
				Padding = 0,
				Children = {
					-- Everyone else finds the tab empty: a row says why.
					upgradeRow({
						Name = "OwnerOnly",
						Text = "Only the crew owner can buy upgrades.",
						Order = 0,
						Visible = scope:Computed(function(use): boolean
							return not use(isOwner)
						end),
					}),
					upgradeRow({
						Name = "UpgradeCapacity",
						Order = 1,
						Detail = "One more place in the crew.",
						Text = scope:Computed(function(use): string
							local view = use(crew)
							local limit = if view then view.MemberLimit else 0
							return `Crew Member Slots {limit} -> {limit + 1}`
						end),
						Visible = scope:Computed(function(use): boolean
							local view = use(crew)
							return view ~= nil
								and use(isOwner)
								and CrewConfig.CanUpgradeCapacity(view.Level, view.MemberLimit)
						end),
						Price = scope:Computed(function(use): string
							local view = use(crew)
							return Bind.formatNumber(CrewConfig.GetCapacityPrice(if view then view.Level else 0))
						end),
						OnClick = function()
							if not sent then
								markSent()
								CrewService.UpgradeCapacity:Fire()
							end
						end,
					}),
					logoRow,
					nameRow,
				},
			}),
		})

		return Kit.Screen(scope, {
			Name = "CrewGui",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				Kit.Window(scope, {
					Title = "Crew Menu",
					Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
					OnClose = context.Close,
					Children = {
						createFrame,
						scope:New("Frame")({
							Name = "InCrewFrame",
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Visible = scope:Computed(function(use): boolean
								return use(crew) ~= nil
							end),
							[Fusion.Children] = {
								crewBand,
								Kit.Stack(scope, {
									Name = "Tabs",
									Gap = Kit.Space.S,
									Position = UDim2.fromOffset(0, CONTENT_TOP),
									Children = tabButtons,
								}),
								Kit.Well(scope, {
									Name = "Page",
									Position = UDim2.fromOffset(PAGE_LEFT, CONTENT_TOP),
									Size = UDim2.new(1, -PAGE_LEFT, 1, -CONTENT_TOP),
									Padding = PAD,
									Children = {
										menuPage,
										playersPage,
										upgradesPage,
									},
								}),

								-- Over the whole content: leaving is asked from two pages.
								dialog({
									Name = "ConfirmTemplate",
									Visible = scope:Computed(function(use): boolean
										return use(confirmation) ~= nil
									end),
									Content = question(scope:Computed(function(use): string
										local pending = use(confirmation)
										return if pending then pending.Text else ""
									end)),
									AcceptText = "Yes",
									DeclineText = "No",
									OnAccept = function()
										local pending = Fusion.peek(confirmation)
										confirmation:set(nil)
										if pending then
											pending.Run()
										end
									end,
									OnDecline = function()
										confirmation:set(nil)
									end,
								}),
								logoSheet,
								nameSheet,
							},
						}),
					},
				}),
			},
		})
	end,
}
