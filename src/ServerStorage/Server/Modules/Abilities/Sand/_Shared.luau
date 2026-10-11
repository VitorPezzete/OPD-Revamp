--!strict
--[[
	Helpers shared by the Sand abilities.

	Flight lock: every legacy Sand power called `AbilityActivated`, which added a "flight
	disabler" for 3 seconds; the Sand flight landed as soon as one existed and could not
	take off until it was gone. That rule is character-wide and lives in
	Server.Modules.FlightLock / AbilityService.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = {}

Shared.FLIGHT_STATUS = "SandFlying"

-- Position of a limb of the character, or of its root when the limb is missing.
function Shared.LimbPosition(entity: any, limbName: string): Vector3
	local limb = entity.Model:FindFirstChild(limbName)
	return if limb and limb:IsA("BasePart") then limb.Position else entity.Root.Position
end

--[[
	Size of a Sand model in ReplicatedStorage.Assets.Models.Fruits.Sand (the instance dump
	has no sizes). The server only reads it to size its hit queries the same way the
	clients size the visual; `fallback` is used when the asset is not there.
]]
function Shared.TemplateSize(fallback: Vector3, ...: string): Vector3
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Sand", ... } do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current.Size else fallback
end

return Shared
