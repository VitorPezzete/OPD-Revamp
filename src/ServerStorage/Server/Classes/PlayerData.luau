--!strict
--[[
	Session wrapper around a ProfileStore profile. The single write path for player
	data: every Set fires Changed, which is what replication and gameplay systems
	subscribe to (replaces the legacy ValueObject tree in Workspace.UserData).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Packages.Signal)
local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local TablePath = require(ReplicatedStorage.Shared.Util.TablePath)

type Observer = (value: any, previous: any) -> ()

local PlayerData = {}
PlayerData.__index = PlayerData

export type PlayerData = typeof(setmetatable(
	{} :: {
		Player: Player,
		Data: DataTypes.PlayerData,
		Changed: Signal.Signal<string, any, any>,
		FirstSessionTime: number,
		_profile: any,
		_observers: { [string]: { Observer } },
	},
	PlayerData
))

function PlayerData.new(player: Player, profile: any): PlayerData
	return setmetatable({
		Player = player,
		Data = profile.Data,
		Changed = Signal.new(),
		FirstSessionTime = profile.FirstSessionTime,
		_profile = profile,
		_observers = {},
	}, PlayerData)
end

function PlayerData.IsActive(self: PlayerData): boolean
	return self._profile:IsActive()
end

function PlayerData.Get(self: PlayerData, path: string): any
	return TablePath.Get(self.Data :: any, path)
end

function PlayerData.Set(self: PlayerData, path: string, value: any)
	if not self:IsActive() then
		return
	end

	local previous = TablePath.Set(self.Data :: any, path, value)
	-- Tables are always announced: callers mutate and re-set them.
	if previous == value and type(value) ~= "table" then
		return
	end

	self.Changed:Fire(path, value, previous)

	-- An observer of "Expertise.Perks" also hears "Expertise.Perks.BuffSpeed.Value".
	for observed, observers in self._observers do
		if observed == path or string.sub(path, 1, #observed + 1) == observed .. "." then
			for _, observer in observers do
				task.spawn(observer, value, previous)
			end
		end
	end
end

-- Adds delta to a numeric path, clamped to [minimum, maximum]. Returns the new value.
function PlayerData.Increment(self: PlayerData, path: string, delta: number, minimum: number?, maximum: number?): number
	local current = self:Get(path)
	assert(type(current) == "number", `PlayerData path "{path}" is not a number`)

	local nextValue = math.clamp(current + delta, minimum or -math.huge, maximum or math.huge)
	self:Set(path, nextValue)
	return nextValue
end

-- Removes amount from a numeric path only if the balance covers it.
function PlayerData.TrySpend(self: PlayerData, path: string, amount: number): boolean
	local current = self:Get(path)
	if type(current) ~= "number" or amount < 0 or current < amount then
		return false
	end

	self:Set(path, current - amount)
	return true
end

-- Calls observer on every change of a path or of anything below it. Returns a disconnect function.
function PlayerData.Observe(self: PlayerData, path: string, observer: Observer): () -> ()
	local observers = self._observers[path]
	if not observers then
		observers = {}
		self._observers[path] = observers
	end
	table.insert(observers, observer)

	return function()
		local index = table.find(observers, observer)
		if index then
			table.remove(observers, index)
		end
	end
end

-- Asks for the profile to be written now instead of at the next autosave (after a trade,
-- so one side of it cannot be saved without the other).
function PlayerData.Save(self: PlayerData)
	if self:IsActive() then
		self._profile:Save()
	end
end

function PlayerData.Destroy(self: PlayerData)
	self.Changed:Destroy()
	table.clear(self._observers)
end

return PlayerData
