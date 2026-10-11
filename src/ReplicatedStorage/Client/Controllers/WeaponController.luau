--!strict
--[[
	Local side of what a held weapon does besides its basic attack (CombatController):

	- the special attack: the "SpFn" action of InputController asks the server for the
	  special of the weapon in hand, aimed where the player points. The animation plays
	  when the server accepts (AttackService.SpecialUsed), so a refused press shows nothing;
	- utility tools and grapples (UtilityConfig): a click uses them;
	- the Yamato box: open while the Yamato is in hand.

	Everything is decided by the server; the local cooldowns only avoid useless requests.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local AttackConfig = require(ReplicatedStorage.Shared.Configs.AttackConfig)
local UtilityConfig = require(ReplicatedStorage.Shared.Configs.UtilityConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)

local SLOT_ATTRIBUTE = "WeaponSlot"
local YAMATO = "Yamato"
local YAMATO_SCREEN = "YamatoGUI"
local SPECIAL_REPEAT = 0.1
local ANIMATION_FADE = 0.1
local ICE_SPEAR = "Ice Spear"
local ROGER = "Roger"
local UNSHEATHE_WEIGHT = 4

-- Specials whose clip is a shared animation, not a child of the tool. Plain Play() in legacy.
local SPECIAL_CLIPS: { [string]: string } = {
	Lollipop = AnimationConfig.Lollipopnimtion,
	[ICE_SPEAR] = AnimationConfig.SpearSpecial,
}

local WeaponController = Knit.CreateController({
	Name = "WeaponController",
})

local CombatController
local InputController
local UIController
local AttackService
local UtilityService

local localPlayer = Players.LocalPlayer
local lastUse: { [string]: number } = {}
local lastSpecial = 0
-- Per weapon slot, like the server cooldown.
local specialReadyAt: { [string]: number } = {}
-- The clip held for as long as the tool is (Ice Spear idle).
local heldTrack: AnimationTrack? = nil

local function getHeldTool(): Tool?
	local character = localPlayer.Character
	return if character then character:FindFirstChildOfClass("Tool") else nil
end

local function playAnimation(animationId: string?, speed: number, weight: number?): AnimationTrack?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not animationId then
		return nil
	end

	-- Loaded (and downloaded) ahead of time by AnimationController. Legacy played all of
	-- these with a plain Play() (fade 0.1) and then adjusted speed / weight.
	return Animations.Play(animator :: Animator, animationId, ANIMATION_FADE, weight or 1, speed)
end

local function requestSpecial()
	local tool = getHeldTool()
	if not tool or tool:GetAttribute(SLOT_ATTRIBUTE) == nil or not AttackConfig.Specials[tool.Name] then
		return
	end

	local now = os.clock()
	local slot = tool:GetAttribute(SLOT_ATTRIBUTE)
	if now < (specialReadyAt[slot] or 0) or now - lastSpecial < SPECIAL_REPEAT then
		return
	end
	lastSpecial = now
	AttackService.Special:Fire(InputController:GetAimPosition())
end

local function onSpecialUsed(weaponName: string, cooldown: number)
	local weapon = WeaponConfig.Weapons[weaponName]
	if weapon then
		specialReadyAt[weapon.Slot] = os.clock() + cooldown
	end

	local special = AttackConfig.Specials[weaponName]
	if not special then
		return
	end

	local clips = (AnimationConfig.Weapons :: any)[weaponName]
	if special.Animation and clips then
		playAnimation(clips[special.Animation], special.AnimationSpeed or 1, special.AnimationWeight)
	elseif SPECIAL_CLIPS[weaponName] then
		playAnimation(SPECIAL_CLIPS[weaponName], 1)
	elseif special.Slash or special.Swing then
		-- A thrown slash is a swing of the weapon, with the swing's own speed and weight.
		CombatController:PlaySwing(weaponName)
	end
end

-- Clips the legacy tools played for as long as they were held (Ice Spear) or once when
-- drawn (Roger, weight 4).
local function onEquipped(tool: Instance)
	if not tool:IsA("Tool") then
		return
	end
	if heldTrack then
		heldTrack:Stop()
		heldTrack = nil
	end
	if tool.Name == ICE_SPEAR then
		heldTrack = playAnimation(AnimationConfig.SpearIdle, 1)
	elseif tool.Name == ROGER then
		playAnimation(AnimationConfig.Weapons.Roger.Unsheat, 1, UNSHEATHE_WEIGHT)
	end
end

local function onUnequipped(tool: Instance)
	if tool.Name == ICE_SPEAR and heldTrack then
		heldTrack:Stop()
		heldTrack = nil
	end
end

local function useTool()
	local tool = getHeldTool()
	local definition = if tool then UtilityConfig.Tools[tool.Name] else nil
	if not tool or not definition then
		return
	end

	local now = os.clock()
	if now - (lastUse[tool.Name] or 0) < definition.Cooldown then
		return
	end
	lastUse[tool.Name] = now

	UtilityService.Use:Fire(InputController:GetAimPosition())

	local clips = (AnimationConfig.Weapons :: any)[tool.Name]
	if clips and definition.Animation then
		playAnimation(clips[definition.Animation], definition.AnimationSpeed or 1)
	end
end

local function watchCharacter(character: Model)
	local function refresh()
		if character:FindFirstChild(YAMATO) then
			UIController:Open(YAMATO_SCREEN)
		else
			UIController:Close(YAMATO_SCREEN)
		end
	end
	heldTrack = nil
	character.ChildAdded:Connect(function(child: Instance)
		if child.Name == YAMATO then
			refresh()
		end
		onEquipped(child)
	end)
	character.ChildRemoved:Connect(function(child: Instance)
		if child.Name == YAMATO then
			refresh()
		end
		onUnequipped(child)
	end)
	refresh()
end

function WeaponController:KnitInit()
	CombatController = Knit.GetController("CombatController")
	InputController = Knit.GetController("InputController")
	UIController = Knit.GetController("UIController")
end

function WeaponController:KnitStart()
	AttackService = Knit.GetService("AttackService")
	UtilityService = Knit.GetService("UtilityService")

	InputController:OnAction("SpFn", function(phase: string)
		if phase == "Begin" then
			requestSpecial()
		end
	end)
	AttackService.SpecialUsed:Connect(onSpecialUsed)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			useTool()
		end
	end)

	localPlayer.CharacterAdded:Connect(watchCharacter)
	if localPlayer.Character then
		watchCharacter(localPlayer.Character)
	end
end

return WeaponController
