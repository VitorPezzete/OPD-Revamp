--!strict
--[[
	Tooltips that follow the mouse. Any screen calls this module; the MouseTip,
	MouseTipPerks and MouseTipPerkPoints screens only render its state.

		Tooltip.show("32.5%")                 Tooltip.hide()
		Tooltip.attach(scope, button, "Text") -- show on hover, hide on leave
		Tooltip.showPerk({ Description = "...", Value = 16, Limit = 20, Icon = "rbxassetid://..." })
		Tooltip.hidePerk()
		Tooltip.showPerkPoints()              Tooltip.hidePerkPoints()

	The legacy game had every hovering LocalScript reach into PlayerGui.MouseTip* and keep
	a HoveringButtons counter that drifted (it needed a "reset on focus lost" hack).
	Here the last caller wins and hiding is idempotent.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

export type PerkTip = {
	Description: string,
	Value: number,
	Limit: number,
	Icon: string?,
	IconColor: Color3?,
	ProgressColor: Color3?,
}

local scope = Fusion.scoped(Fusion)

local Tooltip = {}

-- State read by the tooltip screens.
Tooltip.Text = scope:Value(nil :: string?)
Tooltip.Perk = scope:Value(nil :: PerkTip?)
Tooltip.PerkPoints = scope:Value(false)
-- Mouse position in ScreenGui space (top-left inset removed); only tracked while a tip is up.
Tooltip.Mouse = scope:Value(Vector2.zero)

local tracking: RBXScriptConnection? = nil

local function readMouse()
	local inset = GuiService:GetGuiInset()
	Tooltip.Mouse:set(UserInputService:GetMouseLocation() - inset)
end

local function anyVisible(): boolean
	return Fusion.peek(Tooltip.Text) ~= nil or Fusion.peek(Tooltip.Perk) ~= nil or Fusion.peek(Tooltip.PerkPoints)
end

local function refreshTracking()
	if anyVisible() then
		readMouse()
		if not tracking then
			tracking = UserInputService.InputChanged:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					readMouse()
				end
			end)
		end
	elseif tracking then
		tracking:Disconnect()
		tracking = nil
	end
end

function Tooltip.show(text: string)
	Tooltip.Text:set(text)
	refreshTracking()
end

function Tooltip.hide()
	Tooltip.Text:set(nil)
	refreshTracking()
end

function Tooltip.showPerk(perk: PerkTip)
	Tooltip.Perk:set(perk)
	refreshTracking()
end

function Tooltip.hidePerk()
	Tooltip.Perk:set(nil)
	refreshTracking()
end

function Tooltip.showPerkPoints()
	Tooltip.PerkPoints:set(true)
	refreshTracking()
end

function Tooltip.hidePerkPoints()
	Tooltip.PerkPoints:set(false)
	refreshTracking()
end

-- Shows a text tip while the mouse is over `target`. `text` may be a function, read on enter.
function Tooltip.attach(owner: Scope, target: GuiObject, text: string | () -> string)
	local hovering = false
	table.insert(owner, target.MouseEnter:Connect(function()
		hovering = true
		Tooltip.show(if type(text) == "function" then text() else text)
	end))
	table.insert(owner, target.MouseLeave:Connect(function()
		if hovering then
			hovering = false
			Tooltip.hide()
		end
	end))
	-- A screen closed under the cursor never fires MouseLeave.
	table.insert(owner, function()
		if hovering then
			hovering = false
			Tooltip.hide()
		end
	end)
end

UserInputService.WindowFocusReleased:Connect(function()
	Tooltip.Text:set(nil)
	Tooltip.Perk:set(nil)
	Tooltip.PerkPoints:set(false)
	refreshTracking()
end)

return Tooltip
