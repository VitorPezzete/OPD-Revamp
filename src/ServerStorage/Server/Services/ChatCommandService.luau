--!strict
--[[
	Player chat commands (legacy ServerScriptService.Commands): typed in chat by anyone,
	answered with a message. They are toys and hints, nothing privileged; staff commands
	are the console's (AdminService).

		!8ball <question>   a random answer, shown to the server
		!countdown          5..1 GO for the server, in the chat (one at a time)
		!random             the player's roll, 1-10, shown to the server
		!time               how long this server has been up, in the asker's chat
		!rayleigh           a hint about where the Haki master is (1000 combined levels)

	The legacy remote received the whole chat line from a custom chat box. Any chat system
	can feed this service: Player.Chatted is connected here, and a custom chat GUI's own
	service can call ChatCommandService:Handle(player, text).

	Not ported: !sam (time until Sam's quest) belongs to the compass quest and needs its
	timer; it is one more entry in COMMANDS for whoever owns that timer.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local ChatCommandService = Knit.CreateService({
	Name = "ChatCommandService",
	Client = {},
})

local EIGHT_BALL = {
	"Absolutely not.",
	"Absolutely.",
	"I better not say.",
	"Ask later.",
	"No way.",
	"Yes.",
	"No.",
	"There's no doubt about it.",
	"Outlook not good.",
}

-- What a strong enough player senses, by where the Haki master currently stands.
local RAYLEIGH_HINTS: { { Position: Vector3, Text: string } } = {
	{ Position = Vector3.new(-6051.499, 402.1, -7), Text = "You feel shade" },
	{ Position = Vector3.new(-1181, 218, 1797.5), Text = "You feel hidden" },
	{ Position = Vector3.new(2054, 492, -584.283), Text = "You seek enlightenment" },
	{ Position = Vector3.new(-5159.5, 295, -7800.5), Text = "You feel evil" },
	{ Position = Vector3.new(-2028.5, 239.5, 3382.5), Text = "You hear an echo" },
	{ Position = Vector3.new(6908, 216.5, -1312.414), Text = "You feel cold" },
}
local RAYLEIGH_LEVELS = 1000
local HINT_RADIUS = 5
local MAX_LINE_LENGTH = 200
local COUNTDOWN_FROM = 5
local COUNTDOWN_DELAY = 0.3
-- The legacy colour of the countdown lines in the chat.
local COUNTDOWN_COLOR = Color3.fromRGB(255, 255, 0)

local NotifyService
local StatService

-- Legacy: one command per second per player.
local limiter = RateLimiter.new(1, 1)
local random = Random.new()
local countingDown = false

local function findHakiMaster(): Model?
	-- The quest service knows whether he is around; without it, look for the model.
	local ok, service = pcall(Knit.GetService, "HakiQuestService")
	if ok and type(service) == "table" and type(service.GetMerchant) == "function" then
		return service:GetMerchant()
	end
	local merchants = World.Merchants()
	local model = merchants and merchants:FindFirstChild("QuestHakiMerchant")
	return if model and model:IsA("Model") then model else nil
end

local COMMANDS: { [string]: (player: Player, arguments: { string }) -> () } = {}

COMMANDS["!8ball"] = function(player: Player, arguments: { string })
	if arguments[2] then
		NotifyService:Broadcast(`[8ball] {player.Name}: {EIGHT_BALL[random:NextInteger(1, #EIGHT_BALL)]}`, "Info")
	end
end

COMMANDS["!countdown"] = function()
	if countingDown then
		return
	end
	countingDown = true
	-- After the line that asked for it has reached the chat, as in the legacy game.
	task.delay(COUNTDOWN_DELAY, function()
		for count = COUNTDOWN_FROM, 1, -1 do
			NotifyService:BroadcastChat(`Countdown: {count}`, COUNTDOWN_COLOR)
			task.wait(1)
		end
		NotifyService:BroadcastChat("Countdown: GO!", COUNTDOWN_COLOR)
		countingDown = false
	end)
end

COMMANDS["!random"] = function(player: Player)
	NotifyService:Broadcast(`{player.Name}: {random:NextInteger(1, 10)}`, "Info")
end

COMMANDS["!time"] = function(player: Player)
	local seconds = Workspace.DistributedGameTime
	-- In the asker's chat, not on the screen.
	NotifyService:SendChat(player, string.format("Server time: %dh %dm", seconds // 3600, seconds % 3600 // 60))
end

COMMANDS["!rayleigh"] = function(player: Player)
	local levels = StatService:GetLevels(player)
	if not levels or levels.Melee + levels.Defense + levels.Sniper + levels.Sword < RAYLEIGH_LEVELS then
		NotifyService:Send(player, "You aren't strong enough to sense anything.", "Info")
		return
	end

	local master = findHakiMaster()
	if master and master:IsDescendantOf(Workspace) then
		local position = master:GetPivot().Position
		for _, hint in RAYLEIGH_HINTS do
			if (hint.Position - position).Magnitude <= HINT_RADIUS then
				NotifyService:Send(player, hint.Text, "Info")
				return
			end
		end
	end
	-- Legacy stayed silent when he stood somewhere unlisted; "nothing" is the honest answer.
	NotifyService:Send(player, "You don't sense anything", "Info")
end

-- Runs a chat line if it is a command. Returns whether it was one.
function ChatCommandService:Handle(player: Player, text: unknown): boolean
	if type(text) ~= "string" or #text > MAX_LINE_LENGTH or string.sub(text, 1, 1) ~= "!" then
		return false
	end

	local arguments = string.split(text, " ")
	local command = COMMANDS[string.lower(arguments[1])]
	if not command then
		return false
	end
	if limiter:Consume(player) then
		command(player, arguments)
	end
	return true
end

function ChatCommandService:KnitInit()
	NotifyService = Knit.GetService("NotifyService")
	StatService = Knit.GetService("StatService")
end

function ChatCommandService:KnitStart()
	local function onPlayerAdded(player: Player)
		player.Chatted:Connect(function(message: string)
			ChatCommandService:Handle(player, message)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
	end)
end

return ChatCommandService
