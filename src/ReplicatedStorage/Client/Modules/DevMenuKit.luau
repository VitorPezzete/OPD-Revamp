--!strict
--[[
	Iris idioms shared by the menus the server hands out (Client.Modules.MenuLoader), and
	the shape of the context a tabbed menu gives to each of its tabs. Nothing here says
	what a menu contains: the menus themselves are not part of the client.

	A tab module returns { [tabName] = build }. `build(menu)` runs once, when the menu is
	created: it makes the tab's input states and returns the function that draws it. That
	function only runs on the frames where its tab is the visible one, so a tab costs
	nothing while another is shown.

	Only required by a client that was handed a menu.
]]

export type Menu = {
	Iris: any,
	-- Names and ranges sent by the server with the menu.
	Catalog: { [string]: any },
	Service: any,
	-- Sends a command for the selected target; the answer lands in the request log.
	Run: (action: string, ...any) -> (),
	-- Same for an explicit target (nil: the local player), whatever is selected.
	RunFor: (targetUserId: number?, action: string, ...any) -> (),
	GetTargetId: () -> number?,
	GetTargetName: () -> string,
	IsSelf: () -> boolean,
	-- Latest numbers of the server and of the target; nil until the first answer.
	GetSnapshot: () -> { [string]: any }?,
	GetFps: () -> number,
	Log: { string },
	PushLog: (text: string) -> (),
}

export type Draw = () -> ()
export type Builder = (menu: Menu) -> Draw
export type Tabs = { [string]: Builder }

-- Seconds a confirmation stays armed.
local CONFIRM_SECONDS = 3

local DevMenuKit = {}

local filterCache: { [{ string }]: { Text: string, Result: { string } } } = {}

-- One line of a two-column Iris.Table.
function DevMenuKit.Row(Iris: any, label: string, value: any)
	Iris.Text({ label })
	Iris.NextColumn()
	Iris.Text({ tostring(value) })
	Iris.NextColumn()
end

-- Whole numbers the way a person writes them: 1,250,000. "-" for anything else.
function DevMenuKit.Whole(value: any): string
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return "-"
	end
	local digits = string.format("%.0f", math.abs(value))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return if value < 0 then "-" .. grouped else grouped
end

function DevMenuKit.FormatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%dh %02dm %02ds", whole // 3600, whole % 3600 // 60, whole % 60)
end

-- The entries of `list` that contain `text`, ignoring case. Recomputed only when the text changes.
function DevMenuKit.Filter(list: { string }, text: string): { string }
	if text == "" then
		return list
	end
	local cached = filterCache[list]
	if cached and cached.Text == text then
		return cached.Result
	end

	local wanted = string.lower(text)
	local result = {}
	for _, entry in list do
		if string.find(string.lower(entry), wanted, 1, true) then
			table.insert(result, entry)
		end
	end
	filterCache[list] = { Text = text, Result = result }
	return result
end

-- A combo over a long list, with a box that narrows it. Keeps the selection inside what is shown.
function DevMenuKit.FilteredCombo(Iris: any, label: string, list: { string }, selection: any, filter: any)
	Iris.InputText({ `{label} filter`, "type to narrow the list" }, { text = filter })
	local shown = DevMenuKit.Filter(list, filter:get())
	if #shown > 0 and not table.find(shown, selection:get()) then
		selection:set(shown[1])
	end
	Iris.ComboArray({ label }, { index = selection }, shown)
end

--[[
	A button for things that cannot be undone: the first click arms it for a few seconds
	(the label says so), the second one returns true. `armedUntil` is a number state.
]]
function DevMenuKit.Confirm(Iris: any, label: string, armedUntil: any): boolean
	local now = os.clock()
	local armed = now < armedUntil:get()
	if Iris.Button({ if armed then "Click again to confirm" else label }).clicked() then
		if armed then
			armedUntil:set(0)
			return true
		end
		armedUntil:set(now + CONFIRM_SECONDS)
	end
	return false
end

return DevMenuKit
