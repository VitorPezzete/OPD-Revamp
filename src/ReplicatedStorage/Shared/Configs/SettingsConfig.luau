--!strict
--[[
	Every player setting a client may change (data path "Settings.<Name>").

	The server accepts a change only for a key listed here and only with a value of the
	listed kind and range; the client uses the same table to cycle values and for
	defaults while the data is still loading. Names are the legacy ones, so existing
	profiles keep their settings.
]]

export type Definition = {
	Kind: "boolean" | "integer" | "enum",
	Default: any,
	-- integer
	Min: number?,
	Max: number?,
	-- enum, in cycling order
	Values: { string }?,
}

local function toggle(): Definition
	return { Kind = "boolean", Default = false }
end

local Definitions: { [string]: Definition } = {
	-- Music volume step. Sound.Volume = step * track scale (see MusicConfig).
	Music = { Kind = "integer", Default = 2, Min = 0, Max = 20 },

	-- true hides the custom player list (the legacy button reads "Disable Player List").
	Player_List = toggle(),
	Join_Message = toggle(),
	Hide_Bounty = toggle(),
	-- Closes the shop tab of the menu when the character starts moving.
	Auto_Menu = toggle(),
	Damage_Numbers = toggle(),
	-- Server-read flags: sword hitbox preview and the hit counter HUD.
	Hitbox = toggle(),
	Hit_Counter = toggle(),

	-- Stored and toggled by the legacy game, but nothing ever read them.
	Sun_Mode = toggle(),
	Fog_Mode = toggle(),

	-- "" (never chosen) behaves like "Full".
	Obs_Mode = { Kind = "enum", Default = "", Values = { "Full", "Players Only", "Limited", "Dodge Only" } },
	-- The legacy low graphics setting, applied by the client (GraphicsController).
	Fast_Mode = { Kind = "enum", Default = "Off", Values = { "Off", "On", "Extreme" } },
	ControllerType = { Kind = "enum", Default = "Legacy", Values = { "Legacy", "Shortcut" } },
	-- Chargeable abilities: one press starts the charge, the next press releases it,
	-- instead of holding the key.
	Charge_Toggle = toggle(),
	-- Which interface is mounted (UIConfig.Styles): the rework's, or the old game's with
	-- only the health bar and the player list kept from the rework.
	UI_Style = { Kind = "enum", Default = "Rework", Values = { "Rework", "Legacy" } },
	-- Steps the whole interface is enlarged by (UIConfig.ScaleStep each). 0 is its own size.
	UI_Scale = { Kind = "integer", Default = 0, Min = 0, Max = 5 },
	-- Gamepad and touch only: aim moves onto the nearest target in front, and projectiles
	-- lead a moving target (Projectile.Lead). A mouse is never helped.
	Aim_Assist = { Kind = "boolean", Default = true },
	-- false refuses every trade invitation (TradeService).
	Trade_Requests = { Kind = "boolean", Default = true },
	-- Gamepad and touch only: how hard the camera is pulled towards the locked target
	-- (CameraLockController). 0 turns the camera lock off.
	Camera_Lock = { Kind = "integer", Default = 2, Min = 0, Max = 3 },
	-- Gamepad and touch only: the character always faces where the camera looks, as with
	-- the engine's shift lock on a mouse (CameraLockController).
	Root_Lock = toggle(),
	-- Touch buttons, and for "Custom" the camera and the aim of gamepad and touch (see
	-- ControlsConfig). "Default": the buttons as they always were. "Auto": the same places
	-- and sizes, each button behaving by what its action is. "Custom": the player's Controls
	-- table (camera and aim offsets, buttons moved, resized or given another behaviour).
	-- Only "Custom" reads that table.
	Control_Layout = { Kind = "enum", Default = "Default", Values = { "Default", "Auto", "Custom" } },
}

local SettingsConfig = {}

SettingsConfig.Definitions = Definitions

-- Whether value is acceptable for the setting. Used on both sides; the server is the authority.
function SettingsConfig.IsValid(name: string, value: unknown): boolean
	local definition = Definitions[name]
	if not definition then
		return false
	end

	if definition.Kind == "boolean" then
		return type(value) == "boolean"
	elseif definition.Kind == "integer" then
		if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
			return false
		end
		return value >= (definition.Min or -math.huge) and value <= (definition.Max or math.huge)
	end
	return type(value) == "string" and table.find(definition.Values or {}, value) ~= nil
end

-- The value that follows current when a button cycles the setting (wraps around).
function SettingsConfig.Next(name: string, current: any): any
	local definition = Definitions[name]
	if not definition then
		return current
	end

	if definition.Kind == "boolean" then
		return current ~= true
	elseif definition.Kind == "integer" then
		local minimum, maximum = definition.Min or 0, definition.Max or 0
		if type(current) ~= "number" or current >= maximum or current < minimum then
			return minimum
		end
		return math.floor(current) + 1
	end

	local values = definition.Values or {}
	local index = table.find(values, current) or 0
	return values[index % #values + 1]
end

-- The value before current (integers only matter here: the music volume wraps both ways).
function SettingsConfig.Previous(name: string, current: any): any
	local definition = Definitions[name]
	if not definition or definition.Kind ~= "integer" then
		return SettingsConfig.Next(name, current)
	end

	local minimum, maximum = definition.Min or 0, definition.Max or 0
	if type(current) ~= "number" or current <= minimum or current > maximum then
		return maximum
	end
	return math.ceil(current) - 1
end

return table.freeze(SettingsConfig)
