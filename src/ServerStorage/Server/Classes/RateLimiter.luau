--!strict
--[[
	Token bucket per player. Refill is computed lazily on Consume, so an idle limiter costs nothing.
]]

type Bucket = { Tokens: number, Last: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_burst: number,
		_refill: number,
		_buckets: { [Player]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(burst: number, refillPerSecond: number): RateLimiter
	return setmetatable({
		_burst = burst,
		_refill = refillPerSecond,
		_buckets = {},
	}, RateLimiter)
end

function RateLimiter.Consume(self: RateLimiter, player: Player, cost: number?): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { Tokens = self._burst, Last = now }
		self._buckets[player] = bucket
	end

	bucket.Tokens = math.min(self._burst, bucket.Tokens + (now - bucket.Last) * self._refill)
	bucket.Last = now

	local price = cost or 1
	if bucket.Tokens < price then
		return false
	end

	bucket.Tokens -= price
	return true
end

function RateLimiter.Forget(self: RateLimiter, player: Player)
	self._buckets[player] = nil
end

return RateLimiter
