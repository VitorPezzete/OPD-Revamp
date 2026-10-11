--!strict
--[[
	Bottom-right corner of the spawn menu (hidden once the player has a character): how long this server has been up and, under it, the game version
	(legacy Version). Two right-aligned lines of small text, as the old ones.

	Uptime comes from Workspace.DistributedGameTime, which the engine already replicates;
	the legacy game kept a ServerTime value in Workspace for it. The version string is
	VersionConfig.Version (the legacy Workspace.GlobalReference.Version left the place).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local VersionConfig = require(ReplicatedStorage.Shared.Configs.VersionConfig)

type Scope = Fusion.Scope<typeof(Fusion)>

-- The label has minute resolution.
local REFRESH_SECONDS = 5
-- The old lines on a 1920x1080 screen.
local LINE_SIZE = Vector2.new(408, 30)

return {
	Persistent = true,
	-- Also the rework's version screen: drawn at the legacy scale there too.
	Style = "Legacy",

	Mount = function(scope: Scope, _gui: any, _context: any)
		local uptime = scope:Value("")

		local thread = task.spawn(function()
			while true do
				local seconds = math.floor(Workspace.DistributedGameTime)
				uptime:set(string.format("Server up %dh %dm", seconds // 3600, seconds % 3600 // 60))
				task.wait(REFRESH_SECONDS)
			end
		end)
		table.insert(scope, function()
			task.cancel(thread)
		end)

		local function line(name: string, text: Fusion.UsedAs<string>, order: number): Instance
			return Kit.Label(scope, {
				Name = name,
				Text = text,
				TextSize = Kit.TextSize.Small,
				TextXAlignment = Enum.TextXAlignment.Right,
				Fit = true,
				Size = UDim2.fromOffset(LINE_SIZE.X, LINE_SIZE.Y),
				LayoutOrder = order,
			})
		end

		-- Only on the spawn menu: once the player has a body the corner is the game's.
		local onSpawnMenu = scope:Value(not LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			onSpawnMenu:set(character == nil)
		end))

		return Kit.Screen(scope, {
			Name = "Version",
			Children = {
				Kit.Stack(scope, {
					Name = "Corner",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -Kit.Space.XS, 1, -1),
					Size = UDim2.fromOffset(LINE_SIZE.X, LINE_SIZE.Y * 2),
					Visible = onSpawnMenu,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					Children = {
						line("Time", uptime, 1),
						line("Version", VersionConfig.Version, 2),
					},
				}),
			},
		})
	end,
}
