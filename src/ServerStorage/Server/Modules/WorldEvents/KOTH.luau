--!strict
--[[
	King of the Hill: the players are shuffled into Red and Blue. The map adds capture
	points to the world (nobody is teleported). A team takes a point by being the only
	team on it for ten seconds; every owned point is worth a point per second. First to
	100, or the higher score after five minutes, wins: each member rolls the standard
	reward and is sent to a world spawn. A draw rewards both teams.

	Dying does not eliminate: a member who respawns is still on the team.

	Legacy bug fixed: capture progress belonged to the point, not to a team, so a team
	arriving on a half-captured point finished the enemy's capture for itself. Progress
	now restarts when the capturing team changes.
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local WorldEventTypes = require(ServerStorage.Server.Types.WorldEventTypes)

type Context = WorldEventTypes.Context
type TeamName = "Red" | "Blue"

type CapturePoint = {
	Part: BasePart,
	Label: TextLabel?,
	Particles: ParticleEmitter?,
	Owner: TeamName?,
	Capturing: TeamName?,
	Progress: number,
}

local KOTH = {}

local random = Random.new()

local function findPoints(map: Instance): { CapturePoint }
	local points: { CapturePoint } = {}
	for _, child in map:GetChildren() do
		if child.Name ~= "Capture" or not child:IsA("BasePart") then
			continue
		end
		local billboard = child:FindFirstChild("BillboardGui")
		local label = billboard and billboard:FindFirstChild("T")
		local particles = child:FindFirstChild("P")
		table.insert(points, {
			Part = child,
			Label = if label and label:IsA("TextLabel") then label else nil,
			Particles = if particles and particles:IsA("ParticleEmitter") then particles else nil,
			Owner = nil,
			Capturing = nil,
			Progress = 0,
		})
	end
	return points
end

local function describe(point: CapturePoint, captureSeconds: number): string
	local percent = math.floor(point.Progress / captureSeconds * 100)
	if point.Owner then
		if point.Capturing and point.Capturing ~= point.Owner and point.Progress > 0 then
			return `{point.Capturing} RECAPTURING: {percent}%`
		end
		return `{point.Owner} Team controls`
	elseif point.Capturing and point.Progress > 0 then
		return `{point.Capturing} CAPTURING: {percent}%`
	end
	return "Waiting..."
end

function KOTH.Start(context: Context): (() -> ())?
	local config = context.Config
	local map = context.LoadMap()
	local points = if map then findPoints(map) else {}
	if #points == 0 then
		warn("[KOTH] map or its Capture parts are missing")
		context.Finish()
		return nil
	end

	local teams: { [TeamName]: { Player } } = { Red = {}, Blue = {} }
	local scores: { [TeamName]: number } = { Red = 0, Blue = 0 }
	local timeLeft: number = config.MatchSeconds
	local everyone: { Player } = {}

	local shuffled = table.clone(context.Participants)
	random:Shuffle(shuffled)
	for index, player in shuffled do
		local team: TeamName = if index % 2 == 0 then "Red" else "Blue"
		table.insert(teams[team], player)
		table.insert(everyone, player)
		context.SetTeam(player, team, config.Teams[team])
	end
	context.Notify(teams.Red, "King of the Hill: you are on the Red team!")
	context.Notify(teams.Blue, "King of the Hill: you are on the Blue team!")

	context.Track(Players.PlayerRemoving:Connect(function(player: Player)
		for _, list in { teams.Red, teams.Blue, everyone } do
			local index = table.find(list, player)
			if index then
				table.remove(list, index)
			end
		end
	end))

	local function countOn(point: CapturePoint, team: TeamName): number
		local count = 0
		for _, player in teams[team] do
			local entity = context.GetFighter(player)
			if entity and (entity.Root.Position - point.Part.Position).Magnitude <= config.CaptureRadius then
				count += 1
			end
		end
		return count
	end

	local function updatePoint(point: CapturePoint)
		local red, blue = countOn(point, "Red"), countOn(point, "Blue")
		local alone: TeamName? = if red > 0 and blue == 0 then "Red" elseif blue > 0 and red == 0 then "Blue" else nil

		if not alone then
			point.Progress = math.max(0, point.Progress - config.CaptureDecay)
		elseif alone ~= point.Owner then
			if point.Capturing ~= alone then
				point.Capturing = alone
				point.Progress = 0
			end
			point.Progress += 1
		end

		if point.Progress >= config.CaptureSeconds and point.Capturing then
			point.Owner = point.Capturing
			point.Progress = 0
			local color = config.Teams[point.Owner]
			point.Part.Color = color
			if point.Particles then
				point.Particles.Color = ColorSequence.new(color)
			end
		end

		if point.Owner then
			scores[point.Owner] += config.PointsPerSecond
		end
		if point.Label then
			point.Label.Text = describe(point, config.CaptureSeconds)
		end
	end

	local function finish()
		local winners: { Player }
		if scores.Red == scores.Blue then
			winners = table.clone(everyone)
		else
			winners = table.clone(if scores.Red > scores.Blue then teams.Red else teams.Blue)
		end

		local result = if scores.Red == scores.Blue
			then "King of the Hill ended in a draw!"
			else `King of the Hill: the {if scores.Red > scores.Blue then "Red" else "Blue"} team wins!`
		context.Notify(everyone, result)

		for _, player in winners do
			context.Reward(player)
			context.ReturnToWorld(player)
		end
		context.Finish()
	end

	context.OnTick(function()
		timeLeft -= 1
		for _, point in points do
			updatePoint(point)
		end

		context.SendScore(everyone, { Red = scores.Red, Blue = scores.Blue, TimeLeft = math.max(0, timeLeft) })

		if scores.Red >= config.MaxPoints or scores.Blue >= config.MaxPoints or timeLeft <= 0 or #everyone == 0 then
			finish()
		end
	end)

	return nil
end

return KOTH
