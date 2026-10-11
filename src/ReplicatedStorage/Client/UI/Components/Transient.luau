--!strict
--[[
	Things that show up, stay a few seconds and fade away: toasts, alert lines.

		local toasts = Transient.list(scope, 5)            -- at most 5 at once, oldest dropped
		toasts.Push({ Text = "Saved" }, 4)                 -- data, seconds on screen

		scope:ForValues(toasts.Items, function(_use, rowScope, entry)
			local fade = Transient.fade(rowScope, entry.Seconds, function()
				toasts.Remove(entry)
			end)                                           -- state: 1 hidden -> 0 shown -> 1 hidden
			return UI.Label(rowScope, { Text = entry.Data.Text, Transparency = fade, LayoutOrder = entry.Id })
		end)

	The timers belong to the row scope: an entry pushed out early, or a screen that
	closes, leaves nothing running.

	Not part of Components/init: require it by path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Entry<T> = {
	-- Grows with every push: usable as LayoutOrder.
	Id: number,
	Data: T,
	Seconds: number,
}

export type List<T> = {
	Items: Fusion.Value<{ Entry<T> }>,
	Push: (data: T, seconds: number) -> (),
	Remove: (entry: Entry<T>) -> (),
	Clear: () -> (),
}

local FADE_SECONDS = 0.3

local Transient = {}

Transient.FadeSeconds = FADE_SECONDS

function Transient.list<T>(scope: Scope, max: number?): List<T>
	local items: Fusion.Value<{ Entry<T> }> = scope:Value({} :: { Entry<T> })
	local count = 0

	local function remove(entry: Entry<T>)
		local current = table.clone(Fusion.peek(items))
		local index = table.find(current, entry)
		if index then
			table.remove(current, index)
			items:set(current)
		end
	end

	local function push(data: T, seconds: number)
		count += 1
		local current = table.clone(Fusion.peek(items))
		table.insert(current, { Id = count, Data = data, Seconds = seconds })
		while max and #current > max do
			table.remove(current, 1)
		end
		items:set(current)
	end

	local function clear()
		items:set({})
	end

	return { Items = items, Push = push, Remove = remove, Clear = clear }
end

--[[
	Transparency of one entry (0 shown, 1 hidden): fades in now, fades out after
	`seconds`, then calls `remove`. Give it the scope of the entry's row.
]]
function Transient.fade(rowScope: Scope, seconds: number, remove: () -> ()): Fusion.UsedAs<number>
	local shown = rowScope:Value(false)
	local alive = true
	table.insert(rowScope, function()
		alive = false
	end)

	task.defer(function()
		if alive then
			shown:set(true)
		end
	end)
	task.delay(seconds, function()
		if not alive then
			return
		end
		shown:set(false)
		task.delay(FADE_SECONDS, function()
			if alive then
				remove()
			end
		end)
	end)

	return rowScope:Tween(
		rowScope:Computed(function(use): number
			return if use(shown) then 0 else 1
		end),
		TweenInfo.new(FADE_SECONDS)
	)
end

return Transient
