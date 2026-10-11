--!strict
--[[
	Pictures of gamepad buttons. The engine hands out the image of a button for the pad in
	use (Xbox letters, PlayStation shapes, a generic pad), so nothing is guessed here.

		PadIcons.image("ButtonA")   -- "" when the name is not a button or has no picture
]]
local UserInputService = game:GetService("UserInputService")

local PadIcons = {}

local cache: { [string]: string } = {}

function PadIcons.image(keyName: any): string
	if type(keyName) ~= "string" or keyName == "" then
		return ""
	end
	local cached = cache[keyName]
	if cached then
		return cached
	end

	local image = ""
	local known, keyCode = pcall(function(): Enum.KeyCode
		return (Enum.KeyCode :: any)[keyName]
	end)
	if known and keyCode then
		local ok, result = pcall(UserInputService.GetImageForKeyCode, UserInputService, keyCode)
		image = if ok and type(result) == "string" then result else ""
	end
	cache[keyName] = image
	return image
end

-- The pictures depend on the pad: forgotten when a pad is plugged in or taken out.
UserInputService.GamepadConnected:Connect(function()
	table.clear(cache)
end)
UserInputService.GamepadDisconnected:Connect(function()
	table.clear(cache)
end)

return PadIcons
