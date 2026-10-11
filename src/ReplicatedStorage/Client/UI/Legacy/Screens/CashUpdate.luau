--!strict
--[[
	Floating "+$250" / "-$1,000" whenever the local player's Beri changes (legacy CashUpdate).

	The popup appears the moment the balance changes, one per change, and rises for a
	second through the same spot as the old one: a box a quarter of the way down the middle
	of the screen, from its bottom to its top. Gains are green, spending red (the legacy
	script only showed gains, and only a second after the last one of a burst).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local FLOAT_TIME = 1
local FLOAT_TWEEN = TweenInfo.new(FLOAT_TIME, Enum.EasingStyle.Linear)
local GAIN_COLOR = Color3.fromRGB(0, 255, 0)
local LOSS_COLOR = Color3.fromRGB(255, 70, 70)

-- The old box was a tenth of the screen's height, its text four times as wide.
local HOLDER_SIZE = UDim2.fromOffset(432, 108)
local LABEL_SIZE = UDim2.fromOffset(432, 44)

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")
		local beri = Bind.data(scope, "Economy.Beri", nil)

		-- Popups on their way up: id -> difference.
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
				-- The interface can be swapped before a popup is done.
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
				Kit.Label(itemScope, {
					Name = "Popup",
					Text = `{if difference > 0 then "+" else "-"}${Bind.formatNumber(math.abs(difference))}`,
					TextSize = Kit.TextSize.Title,
					Color = if difference > 0 then GAIN_COLOR else LOSS_COLOR,
					Fit = true,
					Size = LABEL_SIZE,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = itemScope:Computed(function(use): UDim2
						return UDim2.fromScale(0.5, 1 - use(progress))
					end),
				})
		end)

		return Kit.Screen(scope, {
			Name = "CashUpdate",
			-- Over the HUD, like the rework's.
			DisplayOrder = 2,
			Children = {
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
