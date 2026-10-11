--!strict
--[[
	Emotes of the local player.

	- Play / Stop: an emote is an animation on the local Animator (it replicates by
	  itself). It only starts while standing still on the ground and ends as soon as the
	  character walks, plays an action animation (attack, ability) or starts another emote.
	- The Emotes hotkey (Hotkeys.Emotes, LeftAlt by default) shows the emote wheel while
	  it is held, as the legacy PressALT_Emote script did.
	- The dancers around the EmoteMerchant each loop the emote they are named after. The
	  legacy place ran one server script per dancer for that; an NPC's idle dance is pure
	  decoration, so it is played by each client.

	Which emotes exist: EmoteConfig.Free (always available, in wheel button order) and the
	unlockable "CB_Mark<N>" ones (owned flags in data.Emotes). The legacy wheel played the
	marks from ReplicatedStorage.Animations by name - AnimationConfig.CB_Mark<N> - and not
	the ids parked under its buttons, which EmoteConfig.Marks lists; those are only the
	fallback here.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local EmoteConfig = require(ReplicatedStorage.Shared.Configs.EmoteConfig)

local WHEEL_SCREEN = "Emotes"
local MARK_PREFIX = "CB_Mark"
-- Meditate was never sold: everyone has it.
local FREE_MARK = 3
local MERCHANT_NAME = "EmoteMerchant"
local MERCHANT_DANCE = "CB_Mark1"

local EmoteController = Knit.CreateController({
	Name = "EmoteController",
})

local DataController
local UIController

local localPlayer = Players.LocalPlayer
local lastPlay = 0
local stopCurrent: (() -> ())? = nil
local wheelKey: Enum.KeyCode? = nil
local wheelHeld = false

local function toKeyCode(name: any): Enum.KeyCode?
	if type(name) ~= "string" then
		return nil
	end
	local ok, keyCode = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok and keyCode ~= Enum.KeyCode.Unknown then keyCode else nil
end

-- Animation id of an unlockable emote ("CB_Mark7"), nil when it does not exist.
function EmoteController:GetMarkAnimation(markName: string): string?
	local index = tonumber(string.match(markName, `^{MARK_PREFIX}(%d+)$`))
	if not index or not EmoteConfig.Marks[index] then
		return nil
	end
	local id = (AnimationConfig :: any)[markName]
	return if type(id) == "string" then id else EmoteConfig.Marks[index]
end

function EmoteController:OwnsMark(markName: string): boolean
	if markName == MARK_PREFIX .. FREE_MARK then
		return true
	end
	local owned = DataController:Get("Emotes")
	return type(owned) == "table" and owned[markName] == true
end

function EmoteController:Stop()
	if stopCurrent then
		stopCurrent()
	end
end

-- Starts an emote. False when the character cannot emote right now.
function EmoteController:Play(animationId: string): boolean
	local now = os.clock()
	if now - lastPlay < EmoteConfig.ButtonCooldown then
		return false
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator or humanoid.Health <= 0 then
		return false
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Running or humanoid.MoveDirection.Magnitude > 0 then
		return false
	end

	lastPlay = now
	EmoteController:Stop()

	local track = Animations.Play(animator, animationId)

	local connections: { RBXScriptConnection } = {}
	local function stop()
		if stopCurrent ~= stop then
			return
		end
		stopCurrent = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		-- Shared with AnimationController's cache: stopped, never destroyed.
		track:Stop()
	end
	stopCurrent = stop

	table.insert(connections, humanoid.Running:Connect(function(speed: number)
		if speed > 0.1 then
			stop()
		end
	end))
	table.insert(connections, humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0 then
			stop()
		end
	end))
	table.insert(connections, animator.AnimationPlayed:Connect(function(played: AnimationTrack)
		if played ~= track and played.Priority == Enum.AnimationPriority.Action then
			stop()
		end
	end))
	table.insert(connections, humanoid.Died:Connect(stop))
	-- A one-shot emote that ran to its end frees the slot too.
	table.insert(connections, track.Stopped:Connect(stop))
	return true
end

function EmoteController:PlayMark(markName: string): boolean
	local animationId = EmoteController:GetMarkAnimation(markName)
	if not animationId or not EmoteController:OwnsMark(markName) then
		return false
	end
	return EmoteController:Play(animationId)
end

local function loopDance(model: Instance, markName: string)
	local animationId = EmoteController:GetMarkAnimation(markName)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not animationId or not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = Animations.Get(animator :: Animator, animationId)
	track.Looped = true
	track:Play()
end

local function startDancers()
	local merchants = World.WaitMerchants(30)
	local merchant = merchants and merchants:WaitForChild(MERCHANT_NAME, 30)
	if not merchant then
		return
	end
	loopDance(merchant, MERCHANT_DANCE)

	local dancers = merchant:WaitForChild("Dancers", 10)
	if not dancers then
		return
	end
	local function onDancer(dancer: Instance)
		if dancer:IsA("Model") then
			-- The Humanoid may arrive after the model itself.
			dancer:WaitForChild("Humanoid", 10)
			loopDance(dancer, dancer.Name)
		end
	end
	dancers.ChildAdded:Connect(onDancer)
	for _, dancer in dancers:GetChildren() do
		task.spawn(onDancer, dancer)
	end
end

function EmoteController:KnitInit()
	DataController = Knit.GetController("DataController")
	UIController = Knit.GetController("UIController")
end

function EmoteController:KnitStart()
	DataController:Observe("Hotkeys.Emotes", function(hotkey: any)
		wheelKey = if type(hotkey) == "table" then toKeyCode(hotkey.KB) else nil
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not wheelKey or input.KeyCode ~= wheelKey then
			return
		end
		wheelHeld = true
		UIController:Open(WHEEL_SCREEN)
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if wheelHeld and input.KeyCode == wheelKey then
			wheelHeld = false
			UIController:Close(WHEEL_SCREEN)
		end
	end)

	task.spawn(startDancers)
end

return EmoteController
