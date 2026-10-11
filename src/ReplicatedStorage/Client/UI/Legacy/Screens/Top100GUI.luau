--!strict
--[[
	Top 100 bounties, opened from the bounty board in the world (ten rows per page).

	The old window: a square sky-blue board with rounded corners in the middle of the
	screen, "Top 100 Bounties" on a pill at the top, a round red button to close it, ten
	rows (rank, name, bounty, over a bar as long as the bounty is to the highest one) and
	the two arrows with "1 - 10" between them at the bottom. Header, rows and arrows are a
	column now; the rows are the same height and their three texts line up.

	The screen is always mounted and shows its window when the board is clicked: the
	board is looked for and bound inside Mount, and let go with the screen. The ranking is
	fetched from LeaderboardService at that moment and again when the server says it
	changed while the window is up. The ten rows are built once and bound to the current
	page; a page without rows says so (or that it is loading).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local ArrowButton = require(ReplicatedStorage.Client.UI.Legacy.Components.ArrowButton)
local World = require(ReplicatedStorage.Shared.Util.World)

type Scope = Fusion.Scope<typeof(Fusion)>
type Entry = { UserId: number, Name: string, Bounty: number }

local peek = Fusion.peek

local ROWS_PER_PAGE = 10
local PAGES = 10
-- The clickable part of the board, below Workspace.Map.
local BOARD_PATH = { "Islands", "Island11", "Folder", "Board", "PartC" }
local FIND_TIMEOUT = 30

-- The old window on a 1920x1080 screen: a square 70% of the screen's height.
local WINDOW_SIZE = 716
local RIM = 10
local CORNER = 20
local RIM_COLOR = Color3.fromRGB(90, 198, 255)
local BOARD_COLOR = Color3.fromRGB(128, 215, 255)
local ROW_COLOR = Color3.fromRGB(92, 141, 255)
local ARROW_COLOR = Color3.fromRGB(69, 125, 255)

local HEADER_HEIGHT = 56
local NAVIGATION_HEIGHT = 56
local ROW_HEIGHT = 46
local ROW_GAP = 6
local BOARD_HEIGHT = ROWS_PER_PAGE * ROW_HEIGHT + (ROWS_PER_PAGE - 1) * ROW_GAP
local RANK_WIDTH = 56
local BOUNTY_WIDTH = 230
local CLOSE_SIZE = 48

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

		local rows: { Instance } = {}
		for index = 1, ROWS_PER_PAGE do
			local rank = scope:Computed(function(use): number
				return (use(page) - 1) * ROWS_PER_PAGE + index
			end)
			local entry = scope:Computed(function(use): Entry?
				return use(entries)[use(rank)]
			end)

			table.insert(
				rows,
				Kit.Well(scope, {
					Name = `Row{index}`,
					Color = ROW_COLOR,
					Transparency = 0.7,
					Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
					LayoutOrder = index,
					Visible = scope:Computed(function(use): boolean
						return use(entry) ~= nil
					end),
					Children = {
						-- As long as this bounty is to the highest of the ranking.
						scope:New("Frame")({
							Name = "Meter",
							BackgroundColor3 = ROW_COLOR,
							BorderSizePixel = 0,
							Size = scope:Computed(function(use): UDim2
								local current, best = use(entry), use(highest)
								return UDim2.fromScale(
									if current and best > 0 then math.clamp(current.Bounty / best, 0, 1) else 0,
									1
								)
							end),
						}),
						Kit.Label(scope, {
							Name = "Placement",
							Text = scope:Computed(function(use): string
								return tostring(use(rank))
							end),
							TextSize = Kit.TextSize.Small,
							TextXAlignment = Enum.TextXAlignment.Left,
							Fit = true,
							Position = UDim2.fromOffset(Kit.Space.M, 0),
							Size = UDim2.new(0, RANK_WIDTH, 1, 0),
							ZIndex = 2,
						}),
						Kit.Label(scope, {
							Name = "User",
							Text = scope:Computed(function(use): string
								local current = use(entry)
								return if current then current.Name else ""
							end),
							TextSize = Kit.TextSize.Small,
							TextXAlignment = Enum.TextXAlignment.Left,
							Fit = true,
							Position = UDim2.fromOffset(Kit.Space.M + RANK_WIDTH, 0),
							Size = UDim2.new(1, -(RANK_WIDTH + BOUNTY_WIDTH + 3 * Kit.Space.M), 1, 0),
							ZIndex = 2,
						}),
						Kit.Label(scope, {
							Name = "Bounty",
							Text = scope:Computed(function(use): string
								local current = use(entry)
								return if current then Bind.formatNumber(current.Bounty) else ""
							end),
							TextSize = Kit.TextSize.Small,
							TextXAlignment = Enum.TextXAlignment.Right,
							Fit = true,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -Kit.Space.M, 0, 0),
							Size = UDim2.new(0, BOUNTY_WIDTH, 1, 0),
							ZIndex = 2,
						}),
					},
				})
			)
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

		local function turn(step: number)
			page:set(math.clamp(peek(page) + step, 1, PAGES))
		end

		local window = Kit.Panel(scope, {
			Name = "Window",
			Image = "",
			Color = RIM_COLOR,
			Transparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WINDOW_SIZE, WINDOW_SIZE),
			Visible = open,
			Children = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
				Kit.Panel(scope, {
					Name = "Frame",
					Image = "",
					Color = BOARD_COLOR,
					Transparency = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -2 * RIM, 1, -2 * RIM),
					Children = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
						Kit.Stack(scope, {
							Name = "Column",
							Size = UDim2.fromScale(1, 1),
							Gap = Kit.Space.M,
							Padding = Kit.Space.L,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Children = {
								Kit.Panel(scope, {
									Name = "Header",
									Image = "",
									Color = RIM_COLOR,
									Transparency = 0,
									Size = UDim2.new(0.6, 0, 0, HEADER_HEIGHT),
									LayoutOrder = 1,
									Children = {
										scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
										Kit.Label(scope, {
											Name = "Title",
											Text = "Top 100 Bounties",
											TextSize = Kit.TextSize.Heading,
											Fit = true,
											AnchorPoint = Vector2.new(0.5, 0.5),
											Position = UDim2.fromScale(0.5, 0.5),
											Size = UDim2.new(1, -2 * Kit.Space.L, 1, -Kit.Space.S),
										}),
									},
								}),
								scope:New("Frame")({
									Name = "Board",
									BackgroundTransparency = 1,
									Size = UDim2.new(1, 0, 0, BOARD_HEIGHT),
									LayoutOrder = 2,
									[Fusion.Children] = {
										Kit.Stack(scope, {
											Name = "Rows",
											Size = UDim2.fromScale(1, 1),
											Gap = ROW_GAP,
											Children = rows,
										}),
										-- What the board says while the page has no row to show.
										Kit.Label(scope, {
											Name = "Empty",
											Text = scope:Computed(function(use): string
												return if use(loading) then "Loading..." else "No bounties on this page yet."
											end),
											TextSize = Kit.TextSize.Body,
											Fit = true,
											AnchorPoint = Vector2.new(0.5, 0.5),
											Position = UDim2.fromScale(0.5, 0.5),
											Size = UDim2.new(0.9, 0, 0, ROW_HEIGHT),
											Visible = scope:Computed(function(use): boolean
												return use(entries)[(use(page) - 1) * ROWS_PER_PAGE + 1] == nil
											end),
										}),
									},
								}),
								Kit.Stack(scope, {
									Name = "Navigation",
									Direction = "Horizontal",
									Gap = Kit.Space.L,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									LayoutOrder = 3,
									Children = {
										-- Faded at the end of its way; it keeps the gamepad's selection.
										ArrowButton(scope, {
											Name = "Arrow1",
											Direction = "Left",
											Color = ARROW_COLOR,
											Size = UDim2.fromOffset(NAVIGATION_HEIGHT, NAVIGATION_HEIGHT),
											LayoutOrder = 1,
											Faded = scope:Computed(function(use): boolean
												return use(page) <= 1
											end),
											OnClick = function()
												turn(-1)
											end,
										}),
										Kit.Label(scope, {
											Name = "PageLabel",
											Text = scope:Computed(function(use): string
												local current = use(page)
												return `{(current - 1) * ROWS_PER_PAGE + 1} - {current * ROWS_PER_PAGE}`
											end),
											TextSize = Kit.TextSize.Button,
											Size = UDim2.fromOffset(160, NAVIGATION_HEIGHT),
											LayoutOrder = 2,
										}),
										ArrowButton(scope, {
											Name = "Arrow2",
											Direction = "Right",
											Color = ARROW_COLOR,
											Size = UDim2.fromOffset(NAVIGATION_HEIGHT, NAVIGATION_HEIGHT),
											LayoutOrder = 3,
											Faded = scope:Computed(function(use): boolean
												return use(page) >= PAGES
											end),
											OnClick = function()
												turn(1)
											end,
										}),
									},
								}),
							},
						}),
						-- The old round red button; it had nothing written on it.
						Kit.Button(scope, {
							Name = "Close",
							Text = "X",
							Variant = "Red",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -Kit.Space.S, 0, Kit.Space.S),
							Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
							OnClick = close,
							Children = { scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
						}),
					},
				}),
			},
		})
		-- The gamepad closes it like the button does (NavigationController).
		Closers.register(scope, window, close)

		local updated = LeaderboardService.Updated:Connect(function()
			if peek(open) then
				refresh()
			end
		end)
		table.insert(scope, function()
			updated:Disconnect()
		end)

		-- The board can take a while to replicate, and the interface can be swapped
		-- meanwhile: a scope that was cleaned up is not given a connection it would keep.
		local mounted = true
		table.insert(scope, function()
			mounted = false
			-- A late answer must not write into what is left of this mount.
			request += 1
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

		return Kit.Screen(scope, {
			Name = "Top100GUI",
			-- Over the HUD, like the rework's.
			DisplayOrder = 10,
			Children = { window },
		})
	end,
}
