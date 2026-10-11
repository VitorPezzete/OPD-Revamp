--!strict
--[[
	Alice fruit - Wonderland, on a player held inside it (status value: the caster's
	UserId; lasts 3 s and is renewed while the player stays in range).

	The mark itself shows nothing: it is what Tea Party reads to force a cup on the
	player. The inverted world the victim sees comes with it as a status of its own
	(Effects.Status.AliceInverted), shared with Cheshire's Grin, as both were the same
	"Effect1" flag in the legacy game. Wonderland has no model of its own in the old
	game: its Power6 folder is empty.
]]
local function noop() end

return function(_character: Model, _value: any, _isLocal: boolean): () -> ()
	return noop
end
