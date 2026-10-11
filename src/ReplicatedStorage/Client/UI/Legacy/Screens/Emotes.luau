--!strict
--[[
	The emote wheel (legacy StarterGui.Emotes): a column of the free emotes and a column of
	the unlockable ones. Opened by the menu's F tab or while the Emotes hotkey is held.

	The buttons only pick an animation; starting / stopping it is EmoteController's job.
	Unlockable buttons react only once owned (data.Emotes), as in the legacy wheel; until
	then they are drawn as the grey round button.

	The layout has no way out of its own (the wheel was only ever held open): a Close row
	and the line about the merchant are added under the free column, as rows of it.

	Not ported: Meditate (CB_Mark3) also showed the "You feel ..." hint about where the
	Haki quest NPC currently stands, inside the DevilFruitIcons HUD. That belongs to the
	Haki quest; here Meditate is just the emote.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local EmoteConfig = require(ReplicatedStorage.Shared.Configs.EmoteConfig)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)

type Scope = Fusion.Scope<typeof(Fusion)>

-- Buttons of the free column, in the order of EmoteConfig.Free. "2A" (Table Kick) is
-- hidden in the layout, as it was in the legacy GUI.
local FREE_BUTTONS = { "1B", "1A", "1D", "1C", "1E", "1F", "2A", "1G", "1H" }
-- Buttons of the unlockable column: "2A" is CB_Mark1 ... "2P" is CB_Mark16.
local MARK_LETTERS = "ABCDEFGHIJKLMNOP"
local FREE_MARK = "CB_Mark3"

-- The free column ends at 1.6 of the frame (eight rows of 0.2).
local CLOSE_POSITION = UDim2.fromScale(0.05, 1.65)
local HINT_POSITION = UDim2.fromScale(0.05, 1.9)
local HINT_SIZE = UDim2.fromScale(0.9, 0.3)
local HINT = "Locked emotes are sold by the Emote Merchant."
local LOCKED_TRANSPARENCY = 0.5

return {
	Layout = "Emotes",

	Mount = function(scope: Scope, gui: ScreenGui, context: any)
		local EmoteController = Knit.GetController("EmoteController")
		local frame = Bind.find(gui, "Frame")
		frame.Visible = true
		-- Above the menu, as the rework's wheel is.
		gui.DisplayOrder = 10

		local function close()
			context.Close()
		end
		-- A copy of a row of the free column: same font, style and size.
		local sample = Bind.tryFind(frame, FREE_BUTTONS[1])
		if sample and sample:IsA("TextButton") then
			local closeButton = sample:Clone()
			closeButton.Name = "Close"
			closeButton.Text = "Close"
			closeButton.Position = CLOSE_POSITION
			closeButton.Parent = frame
			Bind.click(scope, closeButton, close)

			scope:New("TextLabel")({
				Name = "Hint",
				Parent = frame,
				Position = HINT_POSITION,
				Size = HINT_SIZE,
				BackgroundTransparency = 1,
				FontFace = sample.FontFace,
				Text = HINT,
				TextColor3 = sample.TextColor3,
				TextScaled = true,
				TextStrokeTransparency = sample.TextStrokeTransparency,
				TextWrapped = true,
			})
		end
		-- The gamepad's B closes it like the Close row (NavigationController).
		Closers.register(scope, frame, close)

		for index, buttonName in FREE_BUTTONS do
			local button = Bind.tryFind(frame, buttonName)
			local animationId = EmoteConfig.Free[index]
			if button and button:IsA("GuiButton") and animationId then
				Bind.click(scope, button, function()
					EmoteController:Play(animationId)
				end)
			end
		end

		local owned = Bind.data(scope, "Emotes", {})
		local marks = Bind.find(frame, "Frame")
		for index = 1, #MARK_LETTERS do
			local markName = `CB_Mark{index}`
			local button = Bind.tryFind(marks, "2" .. string.sub(MARK_LETTERS, index, index))
			if not button or not button:IsA("GuiButton") then
				continue
			end

			local isOwned = scope:Computed(function(use): boolean
				local emotes = use(owned)
				return markName == FREE_MARK or (type(emotes) == "table" and emotes[markName] == true)
			end)
			Bind.props(scope, button, {
				Active = isOwned,
				AutoButtonColor = isOwned,
				Style = scope:Computed(function(use)
					return if use(isOwned)
						then Enum.ButtonStyle.RobloxRoundDefaultButton
						else Enum.ButtonStyle.RobloxRoundButton
				end),
				TextTransparency = scope:Computed(function(use)
					return if use(isOwned) then 0 else LOCKED_TRANSPARENCY
				end),
			})
			Bind.click(scope, button, function()
				if Fusion.peek(isOwned) then
					EmoteController:PlayMark(markName)
				end
			end)
		end

		ShopScreen.focus(scope, frame)
	end,
}
