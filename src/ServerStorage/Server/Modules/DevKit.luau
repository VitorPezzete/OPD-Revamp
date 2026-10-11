--!strict
--[[
	Shared pieces of the developer commands (Server.Modules.Dev*Commands).

	A command module returns

		Handlers.<Action>(developer, target, ...) -> ok: boolean, message: string
		Costs.<Action>      rate limit tokens the action spends (1 when absent)
		GetCatalog()        names and ranges the menu needs to offer the module's commands
		GetState(target)    what the menu shows about the target, added to the snapshot

	Nothing in those modules authorises anything: DevService is their only caller and
	runs its gate (Permissions role, or Studio), rate limit and target lookup first.

	Every argument of a handler arrives as `unknown`, straight from a remote. The readers
	below turn one into a value a handler can trust, or nil: numbers are finite and
	clamped to the given range, names are short strings checked against a list or a config.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

export type Handler = (developer: Player, target: Player, ...unknown) -> (boolean, string)

export type CommandModule = {
	Handlers: { [string]: Handler },
	Costs: { [string]: number }?,
	GetCatalog: (() -> { [string]: any })?,
	GetState: ((target: Player) -> { [string]: any })?,
}

local MAX_TEXT = 64

local DevKit = {}

-- A character carrying this status takes no damage (Modules.DamageModifiers.DevGodMode).
DevKit.GodStatus = "DevGod"

function DevKit.Number(value: unknown, minimum: number, maximum: number): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(value, minimum, maximum)
end

-- Same, rounded down. Give it whole bounds.
function DevKit.Integer(value: unknown, minimum: number, maximum: number): number?
	local number = DevKit.Number(value, minimum, maximum)
	return if number then math.floor(number) else nil
end

function DevKit.Name(value: unknown): string?
	if type(value) ~= "string" or #value == 0 or #value > MAX_TEXT then
		return nil
	end
	return value
end

-- A name that is one of `list`.
function DevKit.Member(value: unknown, list: { string }): string?
	local name = DevKit.Name(value)
	return if name and table.find(list, name) then name else nil
end

-- A name that is a key of `dictionary` (a config table).
function DevKit.Key(value: unknown, dictionary: { [string]: any }): string?
	local name = DevKit.Name(value)
	return if name and dictionary[name] ~= nil then name else nil
end

-- A finite Vector3 with every coordinate within +/- limit.
function DevKit.Vector(value: unknown, limit: number): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local vector = value :: Vector3
	if vector.X ~= vector.X or vector.Y ~= vector.Y or vector.Z ~= vector.Z then
		return nil
	end
	if math.max(math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z)) > limit then
		return nil
	end
	return vector
end

-- A Color3 with finite channels clamped to [0, 1].
function DevKit.Color(value: unknown): Color3?
	if typeof(value) ~= "Color3" then
		return nil
	end
	local color = value :: Color3
	if color.R ~= color.R or color.G ~= color.G or color.B ~= color.B then
		return nil
	end
	return Color3.new(math.clamp(color.R, 0, 1), math.clamp(color.G, 0, 1), math.clamp(color.B, 0, 1))
end

function DevKit.Data(target: Player): PlayerData?
	return Knit.GetService("DataService"):GetData(target)
end

-- nil as well in a place without characters (PlaceManifest): every command that needs
-- a body then answers as it does for a player who has not spawned.
function DevKit.Entity(target: Player): CharacterEntity?
	local CharacterService = Optional.Service("CharacterService")
	return if CharacterService then CharacterService:GetPlayerEntity(target) else nil
end

-- The target's entity, only while it is alive.
function DevKit.Living(target: Player): CharacterEntity?
	local entity = DevKit.Entity(target)
	return if entity and not entity.Dead then entity else nil
end

function DevKit.SortedKeys(dictionary: { [string]: any }): { string }
	local keys = {}
	for key in dictionary do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- "1250000", never "1.25e+06": amounts in answers and audit lines stay readable.
function DevKit.Whole(value: number): string
	return string.format("%.0f", value)
end

return DevKit
