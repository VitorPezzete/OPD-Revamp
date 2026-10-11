--!strict
--[[
	Curtain over the screen while the game is not ready to be looked at: from join until
	the player data has arrived, and on every respawn. It then holds for half a second and
	fades out over one.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local LOGO = "rbxassetid://70816647124390"
local HOLD_TIME = 0.5
local FADE_TIME = 1

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local DataController = Knit.GetController("DataController")

		-- 0: curtain down (opaque), 1: lifted.
		local transparency = scope:Value(0)
		local run = 0
		local fading: RBXScriptConnection? = nil
		local waiting: { Disconnect: (any) -> () }? = nil

		local function stopFade()
			if fading then
				fading:Disconnect()
				fading = nil
			end
		end

		local function lift(current: number)
			task.wait(HOLD_TIME)
			if current ~= run then
				return
			end
			local started = os.clock()
			fading = RunService.RenderStepped:Connect(function()
				local alpha = math.clamp((os.clock() - started) / FADE_TIME, 0, 1)
				transparency:set(alpha)
				if alpha >= 1 then
					stopFade()
				end
			end)
		end

		local function drop()
			run += 1
			local current = run
			stopFade()
			transparency:set(0)

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
			stopFade()
			if waiting then
				waiting:Disconnect()
				waiting = nil
			end
		end)

		return UI.Screen(scope, {
			Name = "Blindness",
			DisplayOrder = 101,
			IgnoreGuiInset = true,
			Children = {
				scope:New("Frame")({
					Name = "Curtain",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.Black,
					BackgroundTransparency = transparency,
					Visible = scope:Computed(function(use): boolean
						return use(transparency) < 1
					end),
					[Fusion.Children] = {
						UI.Image(scope, {
							Name = "Logo",
							Image = LOGO,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.45),
							Size = UDim2.fromOffset(480, 322),
							Transparency = transparency,
						}),
						UI.Label(scope, {
							Name = "Message",
							Text = "Waiting for the server to catch up...",
							Variant = "Muted",
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0.45, 180),
							Transparency = transparency,
						}),
					},
				}),
			},
		})
	end,
}
