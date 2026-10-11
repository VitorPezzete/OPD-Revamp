--!strict
--[[
	Numbers in the interface.

	The lettering of the theme has old-style figures (a 0 that reads as an "o", digits of
	uneven height), fine for prose and bad for amounts. Every number shown is therefore
	set in Arimo, inside whatever text it appears in, and so are the symbols < > + -.
	Amounts are written without decimals, thousands separated by dots:

		1234567 -> 1.234.567

		Numerals.format(1234567)
		Numerals.rich("Level 12", false)  -- text with its digit runs wrapped in an Arimo <font> tag

	The components (Label, Button, Badge) call `rich` themselves; a screen only needs
	`format` (also exposed as Bind.formatNumber).
]]
local ARIMO = "rbxasset://fonts/families/Arimo.json"
local OPEN = `<font family="{ARIMO}" weight="bold">`
local CLOSE = "</font>"

local Numerals = {}

Numerals.Font = Font.new(ARIMO, Enum.FontWeight.Bold)
-- The same face at normal weight, for whole pieces set in Arimo (the player list).
Numerals.Plain = Font.new(ARIMO, Enum.FontWeight.Regular)
Numerals.Family = ARIMO

-- Thousands separated by dots. Amounts are whole: any fraction is dropped.
function Numerals.format(value: number): string
	if value ~= value then
		return "0"
	end
	local whole = math.floor(math.abs(value))
	local digits = string.format("%.0f", whole)
	local grouped = string.gsub(string.reverse(digits), "(%d%d%d)", "%1.")
	grouped = string.gsub(string.reverse(grouped), "^%.", "")
	return (if value < 0 and whole > 0 then "-" else "") .. grouped
end

-- Stand-ins for "<" and ">" while a plain text is being escaped.
local LESS, GREATER = "\1", "\2"

local function wrap(plain: string, pattern: string): string
	return (
		string.gsub(plain, pattern, function(run: string): string
			-- Punctuation after the last figure belongs to the sentence, not to the number.
			local tail = string.match(run, "[%.,:]+$") or ""
			return OPEN .. string.sub(run, 1, #run - #tail) .. CLOSE .. tail
		end)
	)
end

function Numerals.has(text: string): boolean
	return string.find(text, "[%d<>%+%-]") ~= nil
end

--[[
	The text as rich text, with every run of digits and symbols set in Arimo. `isRich`
	says whether the input already is rich text: if not, it is escaped first, so "<" and
	"&" still show as themselves.
]]
function Numerals.rich(text: string, isRich: boolean): string
	if not isRich then
		local escaped = string.gsub(text, "&", "&amp;")
		escaped = string.gsub(escaped, "<", LESS)
		escaped = string.gsub(escaped, ">", GREATER)
		escaped = wrap(escaped, "[%d%+%-" .. LESS .. GREATER .. "][%d%.,:%+%-" .. LESS .. GREATER .. "]*")
		escaped = string.gsub(escaped, LESS, "&lt;")
		escaped = string.gsub(escaped, GREATER, "&gt;")
		return escaped
	end

	-- Tags are copied as they are: their attributes are full of digits.
	local pieces = {}
	local position = 1
	while true do
		local first, last = string.find(text, "<[^>]*>", position)
		if not first or not last then
			table.insert(pieces, wrap(string.sub(text, position), "[%d%+%-][%d%.,:%+%-]*"))
			break
		end
		table.insert(pieces, wrap(string.sub(text, position, first - 1), "[%d%+%-][%d%.,:%+%-]*"))
		table.insert(pieces, string.sub(text, first, last))
		position = last + 1
	end
	return table.concat(pieces)
end

return Numerals
