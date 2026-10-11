--!strict
--[[
	Top 100 bounties, opened from the bounty board in the world (ten rows per page).

	The screen is always mounted and shows its window when the board is clicked. The
	ranking is fetched from LeaderboardService at that moment and again when the server
	says it changed while the window is up. The ten rows are bound to the current page.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local World = require(ReplicatedStorage.Shared.Util.World)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type Entry = { UserId: number, Name: string, Bounty: number }

local peek = Fusion.peek

local ROWS_PER_PAGE = 10
local PAGES = 10
-- The clickable part of the board, below Workspace.Map.
local BOARD_PATH = { "Islands", "Island11", "Folder", "Board", "PartC" }
local FIND_TIMEOUT = 30

local ROW_HEIGHT = 48
local ROW_GAP = 6
local NAVIGATION_HEIGHT = 44
local RANK_WIDTH = 64
local BOUNTY_WIDTH = 240
local PODIUM = 3

local function findBoardDetector(): ClickDetector?
	local current = World.WaitResolve(BOARD_PATH, FIND_TIMEOUT)
	local detector = current and current:FindFirstChildOfClass("ClickDetector")
	if not detector then
		warn(`[UI] Top 100 board not found at Workspace.Map.{table.concat(BOARD_PATH, ".")}`)
	end
	return detector
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local LeaderboardService = Knit.GetService("LeaderboardService")

		local open = scope:Value(false)
		local page = scope:Value(1)
		local entries: Fusion.Value<{ Entry }> = scope:Value({} :: { Entry })
		local loading = scope:Value(false)

		local highest = scope:Computed(function(use): number
			local best = 0
			for _, entry in use(entries) do
				best = math.max(best, entry.Bounty)
			end
			return best
		end)

		local rows: { any } = {}
		for index = 1, ROWS_PER_PAGE do
			local rank = scope:Computed(function(use): number
				return (use(page) - 1) * ROWS_PER_PAGE + index
			end)
			local entry = scope:Computed(function(use): Entry?
				return use(entries)[use(rank)]
			end)
			local onPodium = scope:Computed(function(use): boolean
				return use(rank) <= PODIUM
			end)

			rows[index] = UI.Panel(scope, {
				Name = `Row{index}`,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Color = Theme.Colors.Surface,
				Stroke = scope:Computed(function(use): Color3
					return if use(onPodium) then Theme.Colors.BorderStrong else Theme.Colors.Border
				end),
				ClipsDescendants = true,
				Visible = scope:Computed(function(use): boolean
					return use(entry) ~= nil
				end),
				Children = {
					-- The bounty compared with the highest one, drawn behind the text.
					scope:New("Frame")({
						Name = "Meter",
						BackgroundColor3 = Theme.Colors.Primary,
						BackgroundTransparency = 0.72,
						Size = scope:Spring(
							scope:Computed(function(use): UDim2
								local current, best = use(entry), use(highest)
								return UDim2.fromScale(if current and best > 0 then current.Bounty / best else 0, 1)
							end),
							Theme.Motion.SlowSpeed,
							Theme.Motion.Damping
						),
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Medium) }),
						},
					}),
					UI.Label(scope, {
						Name = "Placement",
						Text = scope:Computed(function(use): string
							return `#{use(rank)}`
						end),
						Variant = "Heading",
						Color = scope:Computed(function(use): Color3
							return if use(onPodium) then Theme.Colors.Warning else Theme.Colors.TextMuted
						end),
						Size = UDim2.new(0, RANK_WIDTH, 1, 0),
						ZIndex = 2,
					}),
					UI.Label(scope, {
						Name = "User",
						Text = scope:Computed(function(use): string
							local current = use(entry)
							return if current then current.Name else ""
						end),
						Variant = "BodyBold",
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Position = UDim2.fromOffset(RANK_WIDTH + Theme.Space.S, 0),
						Size = UDim2.new(1, -(RANK_WIDTH + BOUNTY_WIDTH + Theme.Space.S * 2), 1, 0),
						ZIndex = 2,
					}),
					UI.Label(scope, {
						Name = "Bounty",
						Text = scope:Computed(function(use): string
							local current = use(entry)
							return if current then Bind.formatNumber(current.Bounty) else ""
						end),
						Variant = "BodyBold",
						Color = Theme.Colors.Beri,
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -Theme.Space.L, 0, 0),
						Size = UDim2.new(0, BOUNTY_WIDTH, 1, 0),
						ZIndex = 2,
					}),
				},
			})
		end

		-- Only the newest answer is kept: requests can come back out of order.
		local request = 0
		local function refresh()
			request += 1
			local thisRequest = request
			loading:set(true)
			LeaderboardService:GetTop()
				:andThen(function(result: unknown)
					if thisRequest == request and type(result) == "table" then
						entries:set(result :: { Entry })
					end
				end)
				:catch(warn)
				:finally(function()
					if thisRequest == request then
						loading:set(false)
					end
				end)
		end

		local function close()
			open:set(false)
			page:set(1)
		end

		local updated = LeaderboardService.Updated:Connect(function()
			if peek(open) then
				refresh()
			end
		end)
		table.insert(scope, function()
			updated:Disconnect()
		end)

		local mounted = true
		table.insert(scope, function()
			mounted = false
		end)
		task.spawn(function()
			local detector = findBoardDetector()
			if detector and mounted then
				Bind.connect(scope, detector.MouseClick, function()
					refresh()
					open:set(true)
				end)
			end
		end)

		local listHeight = ROWS_PER_PAGE * ROW_HEIGHT + (ROWS_PER_PAGE - 1) * ROW_GAP
		local bodyHeight = listHeight + Theme.Space.M + NAVIGATION_HEIGHT

		return UI.Screen(scope, {
			Name = "Top100GUI",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "Top 100 Bounties",
					Size = UDim2.fromOffset(760, bodyHeight + 52 + Theme.Space.L * 2),
					Visible = open,
					OnClose = close,
					Children = {
						UI.Stack(scope, {
							Name = "Board",
							Size = UDim2.new(1, 0, 0, listHeight),
							Gap = ROW_GAP,
							Children = rows,
						}),
						UI.Label(scope, {
							Name = "Empty",
							Text = scope:Computed(function(use): string
								return if use(loading) then "Loading..." else "No bounties on this page yet."
							end),
							Variant = "Muted",
							Size = UDim2.new(1, 0, 0, listHeight),
							Visible = scope:Computed(function(use): boolean
								return use(entries)[(use(page) - 1) * ROWS_PER_PAGE + 1] == nil
							end),
						}),
						scope:New("Frame")({
							Name = "Navigation",
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.fromScale(0.5, 1),
							Size = UDim2.fromOffset(320, NAVIGATION_HEIGHT),
							BackgroundTransparency = 1,
							[Fusion.Children] = {
								UI.Button(scope, {
									Name = "Arrow1",
									Text = "<",
									Variant = "Secondary",
									Size = UDim2.fromOffset(NAVIGATION_HEIGHT, NAVIGATION_HEIGHT),
									Disabled = scope:Computed(function(use): boolean
										return use(page) <= 1
									end),
									OnClick = function()
										page:set(math.max(1, peek(page) - 1))
									end,
								}),
								UI.Label(scope, {
									Name = "PageLabel",
									Text = scope:Computed(function(use): string
										local current = use(page)
										return `{(current - 1) * ROWS_PER_PAGE + 1} - {current * ROWS_PER_PAGE}`
									end),
									Variant = "BodyBold",
									Size = UDim2.fromScale(1, 1),
								}),
								UI.Button(scope, {
									Name = "Arrow2",
									Text = ">",
									Variant = "Secondary",
									AnchorPoint = Vector2.new(1, 0),
									Position = UDim2.fromScale(1, 0),
									Size = UDim2.fromOffset(NAVIGATION_HEIGHT, NAVIGATION_HEIGHT),
									Disabled = scope:Computed(function(use): boolean
										return use(page) >= PAGES
									end),
									OnClick = function()
										page:set(math.min(PAGES, peek(page) + 1))
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
