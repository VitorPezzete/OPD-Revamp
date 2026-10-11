--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Challenges > Frame > Frame): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): Frame
	return scope:New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(121, 69, 59),
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(1, 0.7),
		ZIndex = 2,
		-- legacy behaviour: ChallengesController (LocalScript, 1548 lines)
		[Children] = {
			require(script.UICorner)(scope),
			require(script.UIStroke)(scope),
			require(script.DailyFrame)(scope),
			require(script.WeeklyFrame)(scope),
			require(script.MonthlyFrame)(scope),
			require(script.ChallengesFrame)(scope),
			require(script.LevelUpFrame)(scope),
		},
	}) :: any
end
