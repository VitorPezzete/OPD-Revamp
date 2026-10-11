--!strict
--[[
	Gravity fruit - state shared by its six abilities. Not an ability: the loader only
	looks modules up by ability name, so this one is never instantiated.

		GravityFlying       replicated  Gravity Flying is on ("<speed>|<colors>")
		GravityAura         replicated  gravity particles on the head, torso and limbs
		                                (value: fruit colors), shown while flying or
		                                charging (Effects.Status.GravityAura)
		GravityAuraSources  server      who is asking for the aura right now

	The legacy script counted aura users in a script-level number shared by every
	branch ("effect += 1 / -= 1"); an interrupted charge left it one too high and the
	aura on forever. Sources are named here, so each ability can only remove its own.

	The legacy "flight disabler" (another power lands Gravity Flying and locks it for
	3 s) is no longer here: it is character-wide, see Server.Modules.FlightLock.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local Shared = {}

Shared.FlyingStatus = "GravityFlying"
Shared.AuraStatus = "GravityAura"
Shared.AuraSourcesStatus = "GravityAuraSources"

Shared.FlightSource = "Flying"

-- Turns the aura on for `source` (pass the fruit color string) or off (pass nil).
function Shared.SetAura(entity: CharacterEntity, source: string, colors: string?)
	local sources = entity:GetStatus(Shared.AuraSourcesStatus)
	if type(sources) ~= "table" then
		if not colors then
			return
		end
		sources = {}
		entity:SetStatus(Shared.AuraSourcesStatus, sources)
	end

	sources[source] = if colors then true else nil

	if next(sources) == nil then
		entity:ClearStatus(Shared.AuraSourcesStatus)
		entity:ClearStatus(Shared.AuraStatus)
	elseif colors and not entity:HasStatus(Shared.AuraStatus) then
		entity:SetStatus(Shared.AuraStatus, colors, nil, true)
	end
end

return Shared
