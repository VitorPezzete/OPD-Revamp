--!strict
--[[
	"You unlocked <weapon>!" banner.

	Nothing is sent for it: the banner watches the replicated Items table and shows
	itself for every weapon that becomes owned while playing, whoever granted it
	(achievements, the Divine Axe, the Tea Kettle, shops...). Several unlocks at once
	are shown one after the other.

	Timing: fades in over 0.5 s, stays until 4.5 s, fades out over 0.5 s.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local FADE = 0.5
local HOLD = 4
local FADE_INFO = TweenInfo.new(FADE, Enum.EasingStyle.Linear)
local PANEL_WIDTH = 640

local HUD = Theme.Transparency.Hud

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")

		local weapon = scope:Value("")
		local shown = scope:Value(false)
		-- 0 shown, 1 hidden.
		local fade = scope:Tween(
			scope:Computed(function(use): number
				return if use(shown) then 0 else 1
			end),
			FADE_INFO
		)

		local known: { [string]: boolean }? = nil
		local queue: { string } = {}
		local showing = false
		local alive = true

		local function showNext()
			if showing or not alive then
				return
			end
			local weaponName = table.remove(queue, 1)
			if not weaponName then
				return
			end

			showing = true
			weapon:set(weaponName)
			shown:set(true)
			task.delay(FADE + HOLD, function()
				if not alive then
					return
				end
				shown:set(false)
				task.delay(FADE, function()
					showing = false
					showNext()
				end)
			end)
		end

		local connection = DataController:Observe("Items", function(items: { [string]: boolean }?)
			if type(items) ~= "table" then
				return
			end

			-- The first snapshot is what the player already owned: nothing to announce.
			local first = known == nil
			local owned: { [string]: boolean } = known or {}
			known = owned
			for name, value in items do
				if value == true and not owned[name] then
					owned[name] = true
					if not first and WeaponConfig.Weapons[name] then
						table.insert(queue, name)
					end
				end
			end
			showNext()
		end)

		table.insert(scope, function()
			alive = false
			connection:Disconnect()
		end)

		return UI.Screen(scope, {
			Name = "NewUnlock",
			DisplayOrder = 40,
			Children = {
				UI.Panel(scope, {
					Name = "Banner",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.25),
					Size = UDim2.fromOffset(PANEL_WIDTH, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Color = Theme.Colors.Background,
					Transparency = scope:Computed(function(use): number
						return HUD + (1 - HUD) * use(fade)
					end),
					Stroke = Theme.Colors.BorderStrong,
					StrokeThickness = 2,
					Radius = Theme.Radius.Large,
					Padding = Theme.Space.L,
					-- Fully faded: out of the way of whatever is under it.
					Visible = scope:Computed(function(use): boolean
						return use(fade) < 1
					end),
					Children = {
						UI.Stack(scope, {
							Name = "Content",
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Gap = Theme.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Children = {
								UI.Label(scope, {
									Name = "Heading",
									Text = "NEW UNLOCK",
									Variant = "Tiny",
									Font = Theme.Fonts.Heading,
									Color = Theme.Colors.Accent,
									Transparency = fade,
									LayoutOrder = 1,
								}),
								UI.Label(scope, {
									Name = "Text",
									Text = scope:Computed(function(use): string
										return `You unlocked {use(weapon)}!`
									end),
									Variant = "Title",
									Scaled = true,
									Transparency = fade,
									Size = UDim2.new(1, 0, 0, 40),
									LayoutOrder = 2,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
