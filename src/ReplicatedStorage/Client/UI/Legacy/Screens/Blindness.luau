--!strict
--[[
	Black curtain over the screen while the game is not ready to be looked at (legacy
	Blindness): from join until the player data has arrived, and on every respawn. It then
	holds for half a second and fades out over one.

	The curtain is one black frame twice the size of the screen, so it also covers the top
	bar. The legacy gui also drew two "loading bars" that counted the player's ValueObjects
	with artificial waits, and a line of text that was never shown; that was theatre and is
	gone. The curtain lifts when the data is here.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_TIME = 0.5
local FADE = TweenInfo.new(1, Enum.EasingStyle.Linear)

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")

		local curtain: Frame = scope:New("Frame")({
			Name = "Frame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(2, 2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Visible = false,
		}) :: any

		local run = 0
		local fadeTween: Tween? = nil
		local waiting: { Disconnect: (any) -> () }? = nil

		local function lift(current: number)
			task.wait(HOLD_TIME)
			if current ~= run then
				return
			end
			local tween = TweenService:Create(curtain, FADE, { BackgroundTransparency = 1 })
			fadeTween = tween
			tween.Completed:Once(function(state: Enum.PlaybackState)
				if state == Enum.PlaybackState.Completed and current == run then
					curtain.Visible = false
				end
			end)
			tween:Play()
		end

		local function drop()
			run += 1
			local current = run
			if fadeTween then
				fadeTween:Cancel()
				fadeTween = nil
			end
			curtain.BackgroundTransparency = 0
			curtain.Visible = true

			if DataController:IsReady() then
				task.spawn(lift, current)
			elseif not waiting then
				waiting = DataController.Ready:Once(function()
					waiting = nil
					-- The newest drop is the one to lift.
					lift(run)
				end)
			end
		end

		Bind.connect(scope, Players.LocalPlayer.CharacterAdded, drop)
		drop()

		table.insert(scope, function()
			run += 1
			if fadeTween then
				fadeTween:Cancel()
			end
			if waiting then
				waiting:Disconnect()
				waiting = nil
			end
		end)

		return Kit.Screen(scope, {
			Name = "Blindness",
			-- Over everything, as the old one.
			DisplayOrder = 101,
			Children = { curtain },
		})
	end,
}
