--!strict
--[[
	Contract between EnemyService and a boss behaviour (Server.Modules.Bosses.<Name>).

	A behaviour is a small class: EnemyService builds one per spawned boss, calls Think
	from its single loop (about 10 times per second while a player is near, far less
	otherwise) and Destroy when the boss dies or is removed. A behaviour never owns a
	loop: timed attacks are timestamps advanced by Think.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local EnemyConfig = require(ServerStorage.Server.Configs.EnemyConfig)

type CharacterEntity = CharacterEntity.CharacterEntity

-- What EnemyService hands to a behaviour.
export type BossHandle = {
	Name: string,
	Entity: CharacterEntity,
	Definition: EnemyConfig.EnemyDefinition,
	Home: CFrame,
	-- Walks towards a point with the shared navigation (straight line, budgeted path fallback).
	Navigate: (goal: Vector3) -> (),
	-- Stops walking.
	Halt: () -> (),
}

export type BossBehaviour = {
	-- target: closest visible player inside FollowDistance (nil when there is none).
	Think: (self: any, target: CharacterEntity?, distance: number, now: number) -> (),
	Destroy: (self: any) -> (),
}

export type BossClass = {
	new: (handle: BossHandle) -> BossBehaviour,
}

return {}
