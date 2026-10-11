--!strict
--[[
	"You unlocked <weapon>!" banner: the old ribbon picture a quarter of the way down the
	middle of the screen, with the line written across it.

	The legacy UnlockWeapon module cloned this ScreenGui into PlayerGui from the server
	for every unlock. Nothing is sent now: the banner watches the replicated Items table
	and shows itself for every weapon that becomes owned while playing, whoever granted
	it (achievements, the Divine Axe, the Tea Kettle, shops...). Several unlocks at once
	are shown one after the other.

	Timing as legacy: fades in over 0.5 s, stays until 4.5 s, fades out over 0.5 s.
	(The legacy script outlived its own gui: Debris removed it after 3 s, mid-banner.)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local FADE = 0.5
local HOLD = 4
local FADE_INFO = TweenInfo.new(FADE, Enum.EasingStyle.Linear)

-- The old ribbon on a 1920x1080 screen (seven times as wide as tall).
local SIZE = Vector2.new(714, 102)
local RIBBON = "rbxassetid://13656415409"

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")

		local text = scope:Value("")
		local shown = scope:Value(false)
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
			text:set(`You unlocked {weaponName}!`)
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

		return Kit.Screen(scope, {
			Name = "NewUnlock",
			-- Over the windows, like the rework's.
			DisplayOrder = 40,
			Children = {
				Kit.Image(scope, {
					Name = "Banner",
					Image = RIBBON,
					ScaleType = Enum.ScaleType.Stretch,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.25),
					Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
					Transparency = fade,
					Visible = scope:Computed(function(use): boolean
						return use(fade) < 1
					end),
					Children = {
						Kit.Label(scope, {
							Name = "Text",
							Text = text,
							TextSize = Kit.TextSize.Title,
							Fit = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(1, -2 * Kit.Space.XL, 0, 44),
							Transparency = fade,
						}),
					},
				}),
			},
		})
	end,
}
