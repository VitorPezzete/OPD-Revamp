--!strict
--[[
	Makes the panel of a legacy tooltip (MouseTip, MouseTipPerks, MouseTipPerkPoints) follow
	the mouse. It reads the mouse position kept by UI.Util.Tooltip (only tracked while a
	tip is up).

		MouseTipFollow.bind(scope, panel)
		MouseTipFollow.bind(scope, panel, 50)   -- design pixels kept between the cursor and the panel

	The panel must be a direct child of the ScreenGui, sized in design pixels (or by its
	content). It is taken out of the panel pinning of ScreenScale: its position is the
	cursor, not a place on the reference screen, and a pinned panel has every position
	rewritten as a share of the screen. The mouse position is turned from real pixels into
	the design pixels the gui's UIScale expects (the legacy screens wrote real pixels, which
	only agree on a 1920x1080 screen).

	The panel keeps the side of the cursor its AnchorPoint puts it on, and is held on the
	screen: near an edge it stops there instead of leaving it. Its size is measured, so a
	tip that grows with its text is held just as well.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)

type Scope = Fusion.Scope<typeof(Fusion)>

local MouseTipFollow = {}

-- `value` kept between `low` and `high`; `low` wins when the panel is larger than the screen.
local function hold(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

function MouseTipFollow.bind(scope: Scope, frame: GuiObject, gap: number?)
	local anchor = frame.AnchorPoint
	local space = gap or 0

	frame:SetAttribute("ScreenScale", false)

	-- Real pixels; the panel is not on screen (and measures nothing) until its first tip.
	local measured = scope:Value(frame.AbsoluteSize)
	table.insert(
		scope,
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			measured:set(frame.AbsoluteSize)
		end)
	)

	scope:Hydrate(frame)({
		Position = scope:Computed(function(use): UDim2
			local mouse = use(Tooltip.Mouse)
			local factor = use(ScreenScale.Factor)
			local viewport = use(ScreenScale.Viewport)
			if factor <= 0 then
				return UDim2.fromOffset(mouse.X, mouse.Y)
			end
			-- The screen as the gui sees it, in design pixels.
			local gui = frame:FindFirstAncestorWhichIsA("ScreenGui")
			local inset = if gui and gui.IgnoreGuiInset then 0 else GuiService:GetGuiInset().Y
			local width = viewport.X / factor
			local height = (viewport.Y - inset) / factor
			local size = use(measured) / factor

			-- The gap is on the side the panel hangs from.
			local x = mouse.X / factor + (if anchor.X >= 0.5 then -space else space)
			local y = mouse.Y / factor
			return UDim2.fromOffset(
				hold(x, anchor.X * size.X, width - (1 - anchor.X) * size.X),
				hold(y, anchor.Y * size.Y, height - (1 - anchor.Y) * size.Y)
			)
		end),
	})
end

return MouseTipFollow
