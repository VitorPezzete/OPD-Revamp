--!strict
--[[
	How chat messages look (legacy StarterPlayerScripts.Chat): "[Name]:" as the prefix and
	the text painted with the sender's rank colour; bubbles in plain black.

	The rank comes from the Player attributes PlayerListService publishes. The legacy
	script read the sender's data folder in Workspace, which no longer exists.

	Lines the server writes in the chat (NotifyService:BroadcastChat, the legacy ChatBot
	script) are shown as system messages of the general channel, in the colour they come with.

	Chat commands (!8ball, !time, ...) are not forwarded from here any more: the server
	listens to Player.Chatted itself (ChatCommandService), so a client cannot fake or
	replay them.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local RankConfig = require(ReplicatedStorage.Shared.Configs.RankConfig)

local ATTRIBUTES = RankConfig.Attributes
local COLORS = RankConfig.ChatColors
local GENERAL_CHANNEL = "RBXGeneral"
local SYSTEM_CHANNEL = "RBXSystem"

local ChatController = Knit.CreateController({
	Name = "ChatController",
})

-- Colour of what this player writes.
function ChatController:GetColor(sender: Player): Color3
	local tester = sender:GetAttribute(ATTRIBUTES.Tester)
	if sender:GetAttribute(ATTRIBUTES.Rank) == "Owner" then
		return COLORS.Owner
	elseif tester == "Helper" then
		return COLORS.Helper
	elseif sender:GetAttribute(ATTRIBUTES.Legendary) == true then
		return COLORS.Legendary
	elseif tester == "Alpha" then
		return COLORS.Alpha
	elseif tester == "Beta" then
		return COLORS.Beta
	end
	return COLORS.Normal
end

local function onIncomingMessage(message: TextChatMessage): TextChatMessageProperties
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if not sender then
		-- System messages keep their own formatting.
		return properties
	end

	properties.PrefixText = `[{sender.Name}]:`
	properties.Text = `<font color="#{ChatController:GetColor(sender):ToHex()}">{message.Text}</font>`
	return properties
end

local function onBubbleAdded(message: TextChatMessage): BubbleChatMessageProperties
	local properties = Instance.new("BubbleChatMessageProperties")
	properties.Text = message.Text
	properties.TextColor3 = RankConfig.BubbleTextColor
	return properties
end

-- Rich text is on in the chat: what is not ours to format is escaped.
local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function onServerLine(text: unknown, color: unknown)
	if type(text) ~= "string" then
		return
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels and (channels:FindFirstChild(GENERAL_CHANNEL) or channels:FindFirstChild(SYSTEM_CHANNEL))
	if channel and channel:IsA("TextChannel") then
		local hex = if typeof(color) == "Color3" then color:ToHex() else "ffffff"
		channel:DisplaySystemMessage(`<font color="#{hex}">{escape(text)}</font>`)
	end
end

function ChatController:KnitStart()
	TextChatService.OnIncomingMessage = onIncomingMessage
	TextChatService.OnBubbleAdded = onBubbleAdded :: any
	Knit.GetService("NotifyService").Chat:Connect(onServerLine)
end

return ChatController
