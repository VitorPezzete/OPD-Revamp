--!strict
--[[
	The places of the experience and which one this server (or client) is running.

	Every place runs this same codebase; what differs is the map and which systems make
	sense there. Code that only belongs to one place asks:

		if PlaceConfig.Role ~= "Main" then return end

	A place id nobody listed (an unpublished Studio file, a copy of the game) counts as
	Main. To test another role in Studio, set the Workspace attribute "PlaceRole" to
	"Raid", "AFK", "Trade" or "Dev" before pressing Play.

	"Dev" is the development place: a baseplate with no map and no spawn screen, where
	systems and abilities are run while they are being written. It never reads or writes
	a live profile (DataService) and everybody in it has the developer menu (AdminConfig).

	No dependencies on purpose: it is required by configs, services and screens alike.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

export type Role = "Main" | "Raid" | "AFK" | "Trade" | "Dev"

-- The game exists twice: the testing experience, where a release is tried first, and the
-- final one, open to the public. Each has its own Main, Raid and AFK places, and a
-- teleport must stay inside the experience it started in.
local TESTING: { [Role]: number } = table.freeze({
	Main = 70580933622015,
	Raid = 81051760483360,
	AFK = 72373943791059,
	Trade = 113700550726661,
	Dev = 104276753440912,
})
local FINAL: { [Role]: number } = table.freeze({
	Main = 112233665771826,
	Raid = 100579164261966,
	AFK = 119985296453597,
})

-- The places of the experience this place belongs to. A place id nobody listed (an
-- unpublished Studio file) is given the testing ones: it must never send to the live game.
local function experience(): { [Role]: number }
	for _, placeId in FINAL do
		if placeId == game.PlaceId then
			return FINAL
		end
	end
	return TESTING
end

local Places = experience()

local OVERRIDE_ATTRIBUTE = "PlaceRole"

local function resolve(): Role
	-- Studio only: a place published with the attribute left on would otherwise run as
	-- another place (the main game paying AFK rewards, for one).
	local override = if RunService:IsStudio() then Workspace:GetAttribute(OVERRIDE_ATTRIBUTE) else nil
	if type(override) == "string" and (Places :: { [string]: number })[override] then
		return override :: Role
	end
	for role, placeId in Places do
		if placeId == game.PlaceId then
			return role
		end
	end
	return "Main"
end

return table.freeze({
	Places = Places,
	-- Decided once, when the place starts: a place does not change role while running.
	Role = resolve(),
})
