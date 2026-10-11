--!strict
--[[
	Renders every NotifyService.Message, in the legacy look: a see-through black strip
	across the top of the screen with white text.

	"Announcement"               the banner, 70% of the screen wide, with its Close button
	                             hanging under it (server restarts, world events). A new one
	                             replaces the old.
	"Info" / "Success" / "Error" / "Warning" short toasts stacked under the banner, coloured by kind,
	                             each gone after its duration. Same strip, one line high.

	Also shows "<player> joined the game." as an Info toast for players who enabled
	Settings.Join_Message (legacy ReplicatedFirst.Message, which wrote it to the chat).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local MAX_TOASTS = 5
local DEFAULT_DURATION = 4
local MAX_DURATION = 30
local TOAST_FADE = TweenInfo.new(0.3)

-- The old banner on a 1920x1080 screen: 70% wide, a tenth of the screen tall, its top half a
-- banner's height below the top.
local BANNER_SIZE = Vector2.new(1344, 100)
local BANNER_TOP = 52
local CLOSE_SIZE = Vector2.new(268, 40)
-- The toasts start under the banner and its button.
local TOASTS_TOP = BANNER_TOP + BANNER_SIZE.Y + CLOSE_SIZE.Y + Kit.Space.M
local TOAST_SIZE = Vector2.new(768, 32)
local STRIP_TRANSPARENCY = 0.3

local KIND_COLORS: { [string]: Color3 } = {
	Info = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(127, 255, 127),
	Error = Color3.fromRGB(255, 110, 110),
	Warning = Color3.fromRGB(255, 200, 80),
}

type Toast = { Id: number, Text: string, Kind: string, Duration: number }

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local NotifyService = Knit.GetService("NotifyService")
		local DataController = Knit.GetController("DataController")

		local alive = true

		-- Banner
		local banner = scope:Value(nil :: string?)
		local bannerTicket = 0

		local function announce(text: string, duration: number)
			bannerTicket += 1
			local ticket = bannerTicket
			banner:set(text)
			task.delay(duration, function()
				if alive and ticket == bannerTicket then
					banner:set(nil)
				end
			end)
		end

		-- Toasts, oldest first. The records keep their identity, so a toast is built once.
		local toasts: Fusion.Value<{ Toast }> = scope:Value({})
		local toastCount = 0

		local function removeToast(id: number)
			local kept: { Toast } = {}
			for _, entry in Fusion.peek(toasts) do
				if entry.Id ~= id then
					table.insert(kept, entry)
				end
			end
			toasts:set(kept)
		end

		local function toast(text: string, kind: string, duration: number)
			toastCount += 1
			local entry: Toast = { Id = toastCount, Text = text, Kind = kind, Duration = duration }
			local list = table.clone(Fusion.peek(toasts))
			table.insert(list, entry)
			while #list > MAX_TOASTS do
				table.remove(list, 1)
			end
			toasts:set(list)

			task.delay(duration + TOAST_FADE.Time, function()
				if alive then
					removeToast(entry.Id)
				end
			end)
		end

		Bind.connect(scope, NotifyService.Message, function(text: unknown, kind: unknown, duration: unknown)
			if type(text) ~= "string" or text == "" then
				return
			end
			local seconds = if type(duration) == "number" and duration == duration
				then math.clamp(duration, 1, MAX_DURATION)
				else DEFAULT_DURATION

			if kind == "Announcement" then
				announce(text, seconds)
			else
				toast(text, if type(kind) == "string" then kind else "Info", seconds)
			end
		end)

		Bind.connect(scope, Players.PlayerAdded, function(player: Player)
			if DataController:Get("Settings.Join_Message") == true then
				toast(`{player.Name} joined the game.`, "Info", DEFAULT_DURATION)
			end
		end)

		table.insert(scope, function()
			alive = false
		end)

		local rows = scope:ForValues(toasts, function(_use, rowScope: Scope, entry: Toast)
			local leaving = rowScope:Value(false)
			local fade = rowScope:Tween(
				rowScope:Computed(function(use): number
					return if use(leaving) then 1 else 0
				end),
				TOAST_FADE
			)
			local ended = false
			table.insert(rowScope, function()
				ended = true
			end)
			task.delay(entry.Duration, function()
				if not ended then
					leaving:set(true)
				end
			end)

			return Kit.Well(rowScope, {
				Name = entry.Kind,
				Size = UDim2.fromOffset(TOAST_SIZE.X, TOAST_SIZE.Y),
				LayoutOrder = entry.Id,
				Transparency = rowScope:Computed(function(use): number
					return STRIP_TRANSPARENCY + (1 - STRIP_TRANSPARENCY) * use(fade)
				end),
				Children = {
					Kit.Label(rowScope, {
						Text = entry.Text,
						TextSize = Kit.TextSize.Body,
						Color = KIND_COLORS[entry.Kind] or KIND_COLORS.Info,
						Fit = true,
						Size = UDim2.new(1, -2 * Kit.Space.M, 1, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Transparency = fade,
					}),
				},
			})
		end)

		return Kit.Screen(scope, {
			Name = "Announcement",
			-- Over the windows, like the rework's: a restart warning is not to be missed.
			DisplayOrder = 40,
			Children = {
				scope:New("Frame")({
					Name = "Banner",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, BANNER_TOP),
					Size = UDim2.fromOffset(BANNER_SIZE.X, BANNER_SIZE.Y + CLOSE_SIZE.Y),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(banner) ~= nil
					end),
					[Fusion.Children] = {
						Kit.Well(scope, {
							Name = "Strip",
							Size = UDim2.fromOffset(BANNER_SIZE.X, BANNER_SIZE.Y),
							Transparency = STRIP_TRANSPARENCY,
							Padding = Kit.Space.M,
							Children = {
								Kit.Label(scope, {
									Name = "Text",
									Text = scope:Computed(function(use): string
										return use(banner) or ""
									end),
									TextSize = Kit.TextSize.Title,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),
						Kit.Well(scope, {
							Name = "CloseStrip",
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, BANNER_SIZE.Y),
							Size = UDim2.fromOffset(CLOSE_SIZE.X, CLOSE_SIZE.Y),
							Transparency = 0.7,
							Children = {
								Kit.Button(scope, {
									Name = "Close",
									Text = "Close",
									Variant = "Ghost",
									Size = UDim2.fromScale(1, 1),
									OnClick = function()
										banner:set(nil)
									end,
								}),
							},
						}),
					},
				}),
				Kit.Stack(scope, {
					Name = "Toasts",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, TOASTS_TOP),
					Size = UDim2.fromOffset(TOAST_SIZE.X, MAX_TOASTS * (TOAST_SIZE.Y + Kit.Space.XS)),
					Gap = Kit.Space.XS,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = rows,
				}),
			},
		})
	end,
}
