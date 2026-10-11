--!strict
--[[
	The Yamato box: type a destination and press Enter to open a gate to it.

	The old rounded plate at the top of the screen, with the text box centred on it (it
	sat in a corner of a plate three times its size).

	Opened and closed by WeaponController while the Yamato is in hand. Only the typed
	name is sent; the server knows the destinations and who may travel (YamatoService).
	The legacy LocalScript fired a RemoteEvent inside the tool with the raw text.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

local MAX_LENGTH = 20

local PLATE_IMAGE = "rbxassetid://1327087642"
local PLATE_SLICE = Rect.new(20, 20, 190, 190)
-- Design pixels.
local PLATE_SIZE = Vector2.new(420, 84)
local PLATE_TOP = 74

return {
	Mount = function(scope: any, _gui: any, context: any): ScreenGui
		local YamatoService = Knit.GetService("YamatoService")

		local textBox: TextBox
		textBox = Kit.TextInput(scope, {
			Name = "TextBox",
			Placeholder = "Destination, then Enter",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -2 * Kit.Space.XL, 0, 40),
			-- Only convenience: the server checks the name whatever its length.
			OnChanged = function(text: string)
				local length = utf8.len(text)
				if length and length > MAX_LENGTH then
					textBox.Text = string.sub(text, 1, (utf8.offset(text, MAX_LENGTH + 1) or (#text + 1)) - 1)
				end
			end,
			OnSubmit = function(text: string)
				textBox.Text = ""
				if text ~= "" and #text <= MAX_LENGTH then
					YamatoService:Travel(text):catch(warn)
				end
			end,
		})
		-- A new destination each time, as the old box did.
		textBox.ClearTextOnFocus = true

		local plate = Kit.Panel(scope, {
			Name = "MainFrame",
			Image = PLATE_IMAGE,
			ImageTransparency = 0.48,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, PLATE_TOP),
			Size = UDim2.fromOffset(PLATE_SIZE.X, PLATE_SIZE.Y),
			Children = { textBox },
		})
		-- The plate is a rounded square: stretched whole, its corners would smear.
		plate.ScaleType = Enum.ScaleType.Slice
		plate.SliceCenter = PLATE_SLICE

		return Kit.Screen(scope, {
			Name = context.Name,
			Children = { plate },
		})
	end,
}
