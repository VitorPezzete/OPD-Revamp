--!strict
--[[
	Floating "+$250" / "-$1,000" whenever the local player's Beri changes.

	The popup appears the moment the balance changes, one per change. Gains are green,
	spending red.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local FLOAT_TIME = 1
local FLOAT_TWEEN = TweenInfo.new(FLOAT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Share of the float after which the popup starts fading.
local FADE_FROM = 0.6

local HOLDER_SIZE = UDim2.fromOffset(420, 120)
-- Money green: the theme's Success is an olive that reads as yellow over the sky.
local GAIN_COLOR = Color3.fromRGB(46, 224, 84)

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")
		local beri = Bind.data(scope, "Economy.Beri", nil)

		-- Popups on screen: id -> difference.
		local popups: Fusion.Value<{ [number]: number }> = scope:Value({})
		local nextId = 0
		local alive = true

		local function popup(difference: number)
			nextId += 1
			local id = nextId

			local added = table.clone(Fusion.peek(popups))
			added[id] = difference
			popups:set(added)

			task.delay(FLOAT_TIME, function()
				if not alive then
					return
				end
				local removed = table.clone(Fusion.peek(popups))
				removed[id] = nil
				popups:set(removed)
			end)
		end

		-- Balance the last popup accounted for. nil until the data has arrived, so the
		-- first sync does not show the whole balance as a gain.
		local accounted: number? = if DataController:IsReady() then Fusion.peek(beri) else nil

		scope:Observer(beri):onChange(function()
			local current = Fusion.peek(beri)
			if type(current) ~= "number" then
				return
			end
			local previous = accounted
			accounted = current
			if previous ~= nil and current ~= previous then
				popup(current - previous)
			end
		end)

		table.insert(scope, function()
			alive = false
		end)

		local labels = scope:ForPairs(popups, function(_use, itemScope: Scope, id: number, difference: number)
			local goal = itemScope:Value(0)
			local progress = itemScope:Tween(goal, FLOAT_TWEEN)
			-- Started once the label exists, outside of this computation.
			task.defer(function()
				goal:set(1)
			end)

			return id,
				UI.Label(itemScope, {
					Name = "Popup",
					Text = `{if difference > 0 then "+" else "-"}${Bind.formatNumber(math.abs(difference))}`,
					Variant = "Title",
					Color = if difference > 0 then GAIN_COLOR else Theme.Colors.Danger,
					Outline = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = itemScope:Computed(function(use): UDim2
						return UDim2.fromScale(0.5, 1 - use(progress))
					end),
					Transparency = itemScope:Computed(function(use): number
						return math.clamp((use(progress) - FADE_FROM) / (1 - FADE_FROM), 0, 1)
					end),
				})
		end)

		return UI.Screen(scope, {
			Name = "CashUpdate",
			DisplayOrder = 2,
			Children = {
				-- The popups rise from the bottom of this box to its top.
				scope:New("Frame")({
					Name = "Popups",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.25),
					Size = HOLDER_SIZE,
					BackgroundTransparency = 1,
					[Fusion.Children] = labels,
				}),
			},
		})
	end,
}
