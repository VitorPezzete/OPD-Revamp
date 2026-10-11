--!strict
--[[
	Contract between WorldEventService and the event modules in Modules.WorldEvents.

	An event module returns { Start = function(context) -> cleanup? }. Start runs once the
	invitation closed with enough players. The event ends by calling context.Finish();
	the service then runs the returned cleanup, drops the map, clears teams and scores.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local WorldEventConfig = require(ServerStorage.Server.Configs.WorldEventConfig)

type CharacterEntity = CharacterEntity.CharacterEntity

export type Context = {
	Name: string,
	Config: WorldEventConfig.EventDefinition,
	-- Players who accepted the invitation and are still in the server.
	Participants: { Player },

	IsFinished: () -> boolean,
	-- Ends the event. Safe to call more than once, and from inside Start.
	Finish: () -> (),
	-- Runs fn once per second while the event is running (the service owns the only loop).
	OnTick: (fn: () -> ()) -> (),
	-- Disconnected / destroyed when the event ends.
	Track: (connection: any) -> (),

	-- Clones Assets.Models.Events.<Config.Map> into Workspace.Instances; destroyed with the event.
	LoadMap: () -> Instance?,
	-- The player's entity if it can fight right now (spawned and alive).
	GetFighter: (player: Player) -> CharacterEntity?,
	-- Teleport onto a spawn part, with a full heal when asked.
	Place: (player: Player, spawn: BasePart, heal: boolean?) -> (),
	-- Team for friendly fire plus the highlight colour; nil clears both. Survives respawns.
	SetTeam: (player: Player, team: string?, color: Color3?) -> (),
	-- Rolls Config.Rewards for the player, pays it and grants the crew experience.
	Reward: (player: Player) -> (),
	-- Teleports a living player to a random world spawn.
	ReturnToWorld: (player: Player) -> (),
	-- Score shown to these players (nil hides it).
	SendScore: (players: { Player }, score: { [string]: any }?) -> (),
	Notify: (players: { Player }, text: string) -> (),
}

export type WorldEvent = {
	Start: (context: Context) -> (() -> ())?,
}

return {}
