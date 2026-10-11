--!strict
--[[
	Discord webhooks: the one place of the server that posts to them.

		WebhookService:Send("FruitDupes", "Duplicated **Magma-123-...**")
		WebhookService:Send("GiftPurchases", { embeds = { { title = "Gift Purchased", ... } } })
		WebhookService:Flag(player, "ChestTravel")          -- suspected exploit, see below

	Send never yields and never errors: it cleans the message, puts it in the queue of its
	channel and returns. Callers are gameplay code (a receipt being granted, a box being
	opened) and must not care whether Discord is slow, down or rate limiting.

	Channels, tokens and every number are in WebhookConfig. The addresses are not in the
	source: they come from ServerStorage.Secrets.Webhooks, a ModuleScript kept in the
	place file only. The service is inert (Send returns at once) outside the places listed
	in WebhookConfig.EnabledPlaceIds, in Studio, and for a channel without an address.

	Delivery
	- One queue per webhook. Every WebhookConfig.FlushSeconds the queues are looked at; a
	  webhook whose interval has passed gets ONE request carrying as many waiting messages
	  as fit (text lines joined up to 2000 characters, up to 10 embeds).
	- The server as a whole stays under WebhookConfig.MaxRequestsPerMinute, far below the
	  500 a minute HttpService shares with everything else.
	- 429: the batch is kept and the webhook waits for as long as Discord says. A response
	  that announces the bucket is empty makes the webhook wait before asking again.
	- Network errors and 5xx: retried a few times, then given up. 400: dropped (it would
	  fail again). 401 / 403 / 404: the webhook is gone, the channel is switched off.
	- A queue that grows past WebhookConfig.MaxQueue loses its oldest message; the next
	  batch says how many were lost.
	- BindToClose sends what it can within WebhookConfig.CloseFlushSeconds.

	Player-provided text: every message is sent with allowed_mentions = { parse = {} },
	so nothing a player typed can ping anybody; control characters are removed and every
	field is cut to Discord's limits.

	Flag(player, reason) is the rework's answer to the legacy "anti-cheat" posts. Those
	scripts banned automatically and announced it. The services now refuse the impossible
	request and call Flag; the report is posted once the player has been flagged often
	enough (WebhookConfig.Flags), and punishing stays a moderation decision.

	Legacy problems fixed: nineteen addresses in plain text across some sixty scripts,
	most posting from the gameplay thread with no pcall (a Discord outage broke box
	openings and bans alike), one request per event with no rate limit of any kind.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local WebhookConfig = require(ServerStorage.Server.Configs.WebhookConfig)

export type Payload = string | { [string]: any }

type Item = { Content: string?, Embeds: { any }?, EmbedSize: number }

type Channel = {
	-- Token of WebhookConfig.Channels: what the logs call this webhook.
	Token: string,
	Url: string,
	Interval: number,
	Queue: { Item },
	-- Encoded body of the batch being delivered; kept until Discord takes it.
	Pending: string?,
	Attempts: number,
	-- Earliest next request: the channel's own interval, or the back-off of a retry.
	NextSendAt: number,
	-- Earliest next request Discord allows (429, or a bucket it announced as empty).
	QuietUntil: number,
	Sending: boolean,
	Dropped: number,
}

type Strikes = { Count: number, WindowStart: number, ReportedAt: number }

-- Discord's limits, with some room: batches are joined with newlines and a drop notice.
local MAX_CONTENT = 1950
local MAX_ITEM_CONTENT = 1800
local MAX_EMBEDS = 10
local MAX_EMBED_CHARS = 5500
local MAX_FIELDS = 25
local TITLE_LENGTH = 256
local DESCRIPTION_LENGTH = 2000
local FIELD_NAME_LENGTH = 256
local FIELD_VALUE_LENGTH = 1000
local FOOTER_LENGTH = 500
local DEFAULT_RATE_LIMIT_SECONDS = 5

local ACTIVE = table.find(WebhookConfig.EnabledPlaceIds, game.PlaceId) ~= nil and not RunService:IsStudio()

local WebhookService = Knit.CreateService({
	Name = "WebhookService",
	Client = {},
})

-- By channel name. Channels of the same token share one Channel.
local channels: { [string]: Channel } = {}
-- Each webhook once, in a stable order.
local webhooks: { Channel } = {}
local requestTimes: { number } = {}
local pausedUntil = 0
local closing = false
local nextStart = 1

local strikes: { [Player]: { [string]: Strikes } } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn(`[WebhookService] {message}`)
	end
end

-- Never print an address: errors of HttpService can quote the request.
local function scrub(problem: any): string
	return (string.gsub(tostring(problem), "https?://%S+", "<address>"))
end

local function loadChannels()
	if not ACTIVE then
		return
	end

	local folder = ServerStorage:FindFirstChild(WebhookConfig.SecretsFolder)
	local module = folder and folder:FindFirstChild(WebhookConfig.SecretsModule)
	if not module or not module:IsA("ModuleScript") then
		warn(`[WebhookService] ServerStorage.{WebhookConfig.SecretsFolder}.{WebhookConfig.SecretsModule} not found: webhooks are off`)
		return
	end

	local ok, secrets = pcall(require, module)
	if not ok or type(secrets) ~= "table" then
		warn("[WebhookService] the Secrets module did not return a table: webhooks are off")
		return
	end

	local byToken: { [string]: Channel } = {}
	local names: { string } = {}
	for name in WebhookConfig.Channels do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in names do
		local token = (WebhookConfig.Channels :: { [string]: string })[name]
		local url = secrets[token]
		if type(url) ~= "string" or string.match(url, "^https://") == nil then
			continue
		end

		local channel = byToken[token]
		if not channel then
			channel = {
				Token = token,
				Url = url,
				Interval = WebhookConfig.ChannelIntervalSeconds,
				Queue = {},
				Pending = nil,
				Attempts = 0,
				NextSendAt = 0,
				QuietUntil = 0,
				Sending = false,
				Dropped = 0,
			}
			byToken[token] = channel
			table.insert(webhooks, channel)
		end
		-- Two channels on one webhook: the slowest interval asked for wins.
		channel.Interval = math.max(channel.Interval, WebhookConfig.ChannelIntervals[name] or 0)
		channels[name] = channel
	end
end

-- Text safe to post: no control characters but the newline, valid UTF-8, cut to `limit`.
local function clean(value: any, limit: number): string
	local text = if type(value) == "string" then value else tostring(value)
	text = string.gsub(text, "%c", function(character: string): string
		return if character == "\n" then character else ""
	end)
	if #text > limit then
		text = string.sub(text, 1, limit - 3)
		-- The cut may have split a multi-byte character.
		for _ = 1, 3 do
			if utf8.len(text) then
				break
			end
			text = string.sub(text, 1, -2)
		end
		text ..= "..."
	end
	if not utf8.len(text) then
		-- Not UTF-8 at all (a client can send any bytes): JSON would be refused.
		text = string.gsub(text, "[\128-\255]", "?")
	end
	return text
end

-- A copy of an embed holding only what the service knows how to bound. Returns its size.
local function cleanEmbed(embed: any): (any, number)
	if type(embed) ~= "table" then
		return nil, 0
	end

	local result: { [string]: any } = {}
	local size = 0
	if embed.title ~= nil then
		result.title = clean(embed.title, TITLE_LENGTH)
		size += #result.title
	end
	if embed.description ~= nil then
		result.description = clean(embed.description, DESCRIPTION_LENGTH)
		size += #result.description
	end
	if type(embed.color) == "number" then
		result.color = math.clamp(math.floor(embed.color), 0, 0xFFFFFF)
	end
	if type(embed.footer) == "table" and embed.footer.text ~= nil then
		result.footer = { text = clean(embed.footer.text, FOOTER_LENGTH) }
		size += #result.footer.text
	end
	-- When the event happened, not when its batch left.
	result.timestamp = if type(embed.timestamp) == "string"
		then clean(embed.timestamp, 40)
		else DateTime.now():ToIsoDate()

	if type(embed.fields) == "table" then
		local fields = {}
		for _, field in embed.fields do
			if type(field) ~= "table" or #fields >= MAX_FIELDS or size > MAX_EMBED_CHARS - FIELD_VALUE_LENGTH then
				continue
			end
			local name = clean(field.name, FIELD_NAME_LENGTH)
			local value = clean(field.value, FIELD_VALUE_LENGTH)
			-- Discord refuses an empty name or value.
			table.insert(fields, {
				name = if name == "" then "-" else name,
				value = if value == "" then "-" else value,
				inline = field.inline == true,
			})
			size += #name + #value
		end
		if #fields > 0 then
			result.fields = fields
		end
	end

	if size == 0 then
		return nil, 0
	end
	return result, size
end

local function toItem(payload: Payload): Item?
	if type(payload) == "string" then
		local content = clean(payload, MAX_ITEM_CONTENT)
		return if content == "" then nil else { Content = content, EmbedSize = 0 }
	elseif type(payload) ~= "table" then
		return nil
	end

	local item: Item = { EmbedSize = 0 }
	if payload.content ~= nil then
		local content = clean(payload.content, MAX_ITEM_CONTENT)
		item.Content = if content == "" then nil else content
	end
	if type(payload.embeds) == "table" then
		local embeds = {}
		for _, embed in payload.embeds do
			local cleaned, size = cleanEmbed(embed)
			if cleaned and #embeds < MAX_EMBEDS and item.EmbedSize + size <= MAX_EMBED_CHARS then
				table.insert(embeds, cleaned)
				item.EmbedSize += size
			end
		end
		item.Embeds = if #embeds > 0 then embeds else nil
	end
	return if item.Content or item.Embeds then item else nil
end

-- Takes as many waiting messages as one request can carry. Returns the encoded body.
local function takeBatch(channel: Channel): string?
	local lines: { string } = {}
	local embeds: { any } = {}
	local length = 0
	local embedSize = 0

	if channel.Dropped > 0 then
		local notice = `*({channel.Dropped} older messages were dropped: the queue was full)*`
		table.insert(lines, notice)
		length = #notice + 1
		channel.Dropped = 0
	end

	local queue = channel.Queue
	local taken = 0
	for _, item in queue do
		local contentLength = if item.Content then #item.Content + 1 else 0
		local embedCount = if item.Embeds then #item.Embeds else 0
		-- The first message always goes: on its own it is within the limits (toItem).
		if
			taken > 0
			and (
				length + contentLength > MAX_CONTENT
				or #embeds + embedCount > MAX_EMBEDS
				or embedSize + item.EmbedSize > MAX_EMBED_CHARS
			)
		then
			break
		end

		if item.Content then
			table.insert(lines, item.Content)
			length += contentLength
		end
		if item.Embeds then
			table.move(item.Embeds, 1, embedCount, #embeds + 1, embeds)
			embedSize += item.EmbedSize
		end
		taken += 1
	end

	local count = #queue
	table.move(queue, taken + 1, count, 1)
	for index = count - taken + 1, count do
		queue[index] = nil
	end

	-- parse = {} encodes as an empty JSON array: no mention in the message may ping.
	local body: { [string]: any } = { allowed_mentions = { parse = {} } }
	if #lines > 0 then
		body.content = table.concat(lines, "\n")
	end
	if #embeds > 0 then
		body.embeds = embeds
	end
	if not body.content and not body.embeds then
		return nil
	end

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, body)
	if not ok then
		warnOnce(`a batch for {channel.Token} could not be encoded and was dropped`)
		return nil
	end
	return encoded
end

-- Header names arrive in whatever case the proxy in front of Discord used.
local function getHeader(response: any, name: string): string?
	if type(response.Headers) ~= "table" then
		return nil
	end
	for key, value in response.Headers do
		if type(key) == "string" and string.lower(key) == name then
			return tostring(value)
		end
	end
	return nil
end

-- Seconds Discord wants this webhook to stay quiet after a 429, and whether it is global.
local function readRateLimit(response: any): (number, boolean)
	local seconds = tonumber(getHeader(response, "x-ratelimit-reset-after"))
	local isGlobal = getHeader(response, "x-ratelimit-global") == "true"

	local ok, body = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if ok and type(body) == "table" then
		isGlobal = isGlobal or body.global == true
		local retryAfter = tonumber(body.retry_after)
		if not seconds and retryAfter then
			-- Seconds in the current API; old API versions answered in milliseconds.
			seconds = if retryAfter > WebhookConfig.MaxRateLimitSeconds then retryAfter / 1000 else retryAfter
		end
	end

	seconds = seconds or tonumber(getHeader(response, "retry-after")) or DEFAULT_RATE_LIMIT_SECONDS
	return math.clamp(seconds :: number, 1, WebhookConfig.MaxRateLimitSeconds) + 0.5, isGlobal
end

-- The batch failed for a reason that may pass: try again later, a few times.
local function retryLater(channel: Channel, reason: string)
	channel.Attempts += 1
	if channel.Attempts >= WebhookConfig.MaxAttempts then
		warn(`[WebhookService] {channel.Token}: batch given up after {channel.Attempts} attempts ({reason})`)
		channel.Pending = nil
		channel.Attempts = 0
		return
	end
	channel.NextSendAt = os.clock() + WebhookConfig.RetrySeconds * channel.Attempts
end

-- Yields: always run in its own thread.
local function post(channel: Channel)
	local body = channel.Pending
	if not body then
		return
	end

	channel.Sending = true
	local ok, response: any = pcall(HttpService.RequestAsync, HttpService, {
		Url = channel.Url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})
	channel.Sending = false

	local now = os.clock()
	-- While closing there is no next interval to wait for.
	channel.NextSendAt = now + (if closing then 0.5 else channel.Interval)

	if not ok or type(response) ~= "table" then
		retryLater(channel, scrub(response))
		return
	end

	local status: number = response.StatusCode
	if status >= 200 and status < 300 then
		channel.Pending = nil
		channel.Attempts = 0
		if getHeader(response, "x-ratelimit-remaining") == "0" then
			local reset = tonumber(getHeader(response, "x-ratelimit-reset-after"))
			if reset then
				channel.QuietUntil = now + math.clamp(reset, 0, WebhookConfig.MaxRateLimitSeconds)
			end
		end
	elseif status == 429 then
		-- Not an attempt: Discord took nothing, the same batch goes again afterwards.
		local seconds, isGlobal = readRateLimit(response)
		channel.QuietUntil = now + seconds
		if isGlobal then
			pausedUntil = math.max(pausedUntil, now + seconds)
		end
	elseif status == 401 or status == 403 or status == 404 then
		warn(`[WebhookService] {channel.Token}: Discord answered {status}, the webhook is gone: channel switched off`)
		channel.Pending = nil
		table.clear(channel.Queue)
		for name, other in channels do
			if other == channel then
				channels[name] = nil
			end
		end
		local index = table.find(webhooks, channel)
		if index then
			table.remove(webhooks, index)
		end
	elseif status >= 500 then
		retryLater(channel, `HTTP {status}`)
	else
		-- Malformed for Discord: it would be refused again.
		warn(`[WebhookService] {channel.Token}: batch refused with HTTP {status} and dropped`)
		channel.Pending = nil
		channel.Attempts = 0
	end
end

-- Counts a request against the server's own budget. False when the minute is spent.
local function takeBudget(now: number): boolean
	while requestTimes[1] and now - requestTimes[1] >= 60 do
		table.remove(requestTimes, 1)
	end
	if #requestTimes >= WebhookConfig.MaxRequestsPerMinute then
		return false
	end
	table.insert(requestTimes, now)
	return true
end

-- Starts a request for every webhook that has something to send and may send now.
-- Returns whether anything is still waiting or on its way.
local function step(): boolean
	local now = os.clock()
	local count = #webhooks
	local busy = false
	-- A different webhook goes first each time, so a tight budget starves none of them.
	nextStart = if nextStart >= count then 1 else nextStart + 1

	for offset = 0, count - 1 do
		local channel = webhooks[(nextStart - 1 + offset) % count + 1]
		if not channel then
			continue
		end
		if channel.Sending then
			busy = true
			continue
		end
		if not channel.Pending and #channel.Queue == 0 and channel.Dropped == 0 then
			continue
		end

		busy = true
		if now < math.max(channel.NextSendAt, channel.QuietUntil, pausedUntil) then
			continue
		end
		if not channel.Pending then
			channel.Pending = takeBatch(channel)
		end
		if channel.Pending and takeBudget(now) then
			task.spawn(post, channel)
		end
	end
	return busy
end

local function flushOnClose()
	closing = true
	local deadline = os.clock() + WebhookConfig.CloseFlushSeconds
	for _, channel in webhooks do
		-- The interval no longer matters; a rate limit Discord announced (QuietUntil) does.
		if channel.Attempts == 0 then
			channel.NextSendAt = 0
		end
	end
	while step() and os.clock() < deadline do
		task.wait(0.2)
	end
end

--[[
	Queues a message for a channel of WebhookConfig.Channels. `payload` is the text of the
	message, or a table in Discord's own shape: { content = "...", embeds = { ... } }
	(of an embed: title, description, color, fields, footer.text, timestamp).
	Never yields, never errors; does nothing where webhooks are off.
]]
function WebhookService:Send(channelName: string, payload: Payload)
	local channel = channels[channelName]
	if not channel then
		if (WebhookConfig.Channels :: { [string]: string })[channelName] == nil then
			warnOnce(`"{tostring(channelName)}" is not a channel of WebhookConfig.Channels`)
		end
		return
	end

	local ok, item = pcall(toItem, payload)
	if not ok or not item then
		return
	end

	table.insert(channel.Queue, item)
	if #channel.Queue > WebhookConfig.MaxQueue then
		table.remove(channel.Queue, 1)
		channel.Dropped += 1
	end
end

-- True when a message sent to this channel would be posted (place enabled, address known).
function WebhookService:IsOn(channelName: string): boolean
	return channels[channelName] ~= nil
end

--[[
	Reports a request only an exploit sends (reasons: WebhookConfig.Flags). Call it every
	time the request is refused: the report is posted once the player has reached the
	reason's strike count within its window, then not again for a while.
	`detail` is appended to the report (what was asked for; it may be player text).
]]
function WebhookService:Flag(player: Player, reason: string, detail: string?)
	local flag = WebhookConfig.Flags[reason]
	if not flag then
		warnOnce(`"{tostring(reason)}" is not a reason of WebhookConfig.Flags`)
		return
	end
	if not channels[flag.Channel] then
		return
	end

	local now = os.clock()
	local reasons = strikes[player]
	if not reasons then
		-- A flag may arrive just after PlayerRemoving: do not keep a gone player.
		if not player:IsDescendantOf(Players) then
			return
		end
		reasons = {}
		strikes[player] = reasons
	end
	local record = reasons[reason]
	if not record then
		record = { Count = 0, WindowStart = now, ReportedAt = -math.huge }
		reasons[reason] = record
	end

	if now - record.WindowStart > flag.Window then
		record.Count = 0
		record.WindowStart = now
	end
	record.Count += 1
	if record.Count < flag.Strikes or now - record.ReportedAt < WebhookConfig.FlagCooldownSeconds then
		return
	end

	local count = record.Count
	record.Count = 0
	record.WindowStart = now
	record.ReportedAt = now

	local times = if count > 1 then ` ({count} times in {flag.Window}s)` else ""
	local extra = if detail and detail ~= "" then `: **{clean(detail, 200)}**` else ""
	WebhookService:Send(
		flag.Channel,
		`**{player.Name}** ({player.UserId}) {flag.Text}{times}{extra}. **Flagged**, no automatic ban.`
	)
end

function WebhookService:KnitStart()
	if #webhooks == 0 then
		return
	end

	task.spawn(function()
		while not closing do
			task.wait(WebhookConfig.FlushSeconds)
			-- A bug here must not end the loop: the queues would fill and stay full.
			local ok, problem = pcall(step)
			if not ok then
				warnOnce(`flush failed: {scrub(problem)}`)
			end
		end
	end)

	game:BindToClose(flushOnClose)

	Players.PlayerRemoving:Connect(function(player: Player)
		strikes[player] = nil
	end)
end

loadChannels()

return WebhookService
