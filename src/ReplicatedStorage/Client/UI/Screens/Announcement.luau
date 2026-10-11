--!strict
--[[
	Renders every NotifyService.Message, upper centre of the screen.

	"Announcement"               a banner with a Close button (server restarts, world
	                             events). A new one replaces the old; it also leaves by
	                             itself after its duration.
	"Info" / "Success" / "Error" short toasts stacked under the banner, coloured by kind,
	                             each gone after its duration. At most five at once.

	Also shows "<player> joined the game." as an Info toast for players who enabled
	Settings.Join_Message.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local Transient = require(ReplicatedStorage.Client.UI.Components.Transient)

type Scope = Theme.Scope
type Toast = { Text: string, Kind: string }

local MAX_TOASTS = 5
local DEFAULT_DURATION = 4
local MAX_DURATION = 30

-- Below the health / haki bars and the KOTH scoreboard.
local TOP_OFFSET = 196
local BANNER_WIDTH = 760
local TOAST_MAX_WIDTH = 720

local KIND_COLORS: { [string]: Color3 } = {
	Info = Theme.Colors.Text,
	Success = Theme.Colors.Success,
	Error = Theme.Colors.Danger,
	Warning = Theme.Colors.Warning,
}

local HUD = Theme.Transparency.Hud

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local NotifyService = Knit.GetService("NotifyService")
		local DataController = Knit.GetController("DataController")

		local alive = true
		table.insert(scope, function()
			alive = false
		end)

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

		-- Toasts
		local toasts = Transient.list(scope, MAX_TOASTS) :: Transient.List<Toast>

		local function buildToast(rowScope: Scope, entry: Transient.Entry<Toast>): Frame
			local fade = Transient.fade(rowScope, entry.Seconds, function()
				toasts.Remove(entry)
			end)
			local color = KIND_COLORS[entry.Data.Kind] or KIND_COLORS.Info

			local label = UI.Label(rowScope, {
				Name = "Text",
				Text = entry.Data.Text,
				Variant = "BodyBold",
				Color = color,
				Wrapped = true,
				Transparency = fade,
			})
			-- Long messages wrap instead of running off the screen.
			rowScope:New("UISizeConstraint")({
				MaxSize = Vector2.new(TOAST_MAX_WIDTH, math.huge),
				Parent = label,
			})

			return UI.Panel(rowScope, {
				Name = entry.Data.Kind,
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = entry.Id,
				Color = Theme.Colors.Background,
				Transparency = rowScope:Computed(function(use): number
					return HUD + (1 - HUD) * use(fade)
				end),
				Stroke = color,
				Radius = Theme.Radius.Medium,
				Padding = Theme.Space.M,
				Children = { label },
			})
		end

		local function toast(text: string, kind: string, duration: number)
			toasts.Push({ Text = text, Kind = kind }, duration)
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

		return UI.Screen(scope, {
			Name = "Announcement",
			DisplayOrder = 40,
			Children = {
				UI.Stack(scope, {
					Name = "Messages",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
					Gap = Theme.Space.S,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = {
						UI.Panel(scope, {
							Name = "Banner",
							Size = UDim2.fromOffset(BANNER_WIDTH, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							LayoutOrder = 0,
							Color = Theme.Colors.Background,
							Transparency = HUD,
							Stroke = Theme.Colors.BorderStrong,
							StrokeThickness = 2,
							Radius = Theme.Radius.Large,
							Padding = Theme.Space.L,
							Visible = scope:Computed(function(use): boolean
								return use(banner) ~= nil
							end),
							Children = {
								UI.Stack(scope, {
									Name = "Content",
									Size = UDim2.fromScale(1, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									Gap = Theme.Space.M,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									Children = {
										UI.Label(scope, {
											Name = "Heading",
											Text = "ANNOUNCEMENT",
											Variant = "Tiny",
											Font = Theme.Fonts.Heading,
											Color = Theme.Colors.Accent,
											LayoutOrder = 1,
										}),
										UI.Label(scope, {
											Name = "Text",
											Text = scope:Computed(function(use): string
												return use(banner) or ""
											end),
											Variant = "Heading",
											Wrapped = true,
											Size = UDim2.fromScale(1, 0),
											AutomaticSize = Enum.AutomaticSize.Y,
											LayoutOrder = 2,
										}),
										UI.Button(scope, {
											Name = "Close",
											Text = "Close",
											Variant = "Secondary",
											TextSize = Theme.TextSize.Small,
											Size = UDim2.fromOffset(140, 34),
											LayoutOrder = 3,
											OnClick = function()
												banner:set(nil)
											end,
										}),
									},
								}),
							},
						}),
						scope:ForValues(toasts.Items, function(_use, rowScope: any, entry: Transient.Entry<Toast>)
							return buildToast(rowScope, entry)
						end),
					},
				}),
			},
		})
	end,
}
