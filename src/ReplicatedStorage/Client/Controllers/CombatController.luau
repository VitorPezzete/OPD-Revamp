--!strict
--[[
	Local side of basic attacks and the observation dodge (haki keys live in InputController).

	Clicking with a weapon equipped asks the server to attack and plays the swing
	animation right away (the Animator replicates it to everyone). A tap on the world
	(touch) and the right trigger (gamepad) arrive as the "Attack" action of
	InputController, which also aims every swing. Damage, cooldown and
	hit detection are entirely the server's; the local cooldown only avoids spam.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local AttackConfig = require(ReplicatedStorage.Shared.Configs.AttackConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)

local SLOT_ATTRIBUTE = "WeaponSlot"
-- Every legacy swing was a plain Play() (fade 0.1) followed by AdjustSpeed / AdjustWeight.
local SWING_FADE = 0.1

--[[
	What a basic attack plays, as the legacy tool scripts did. Almost every sword swung
	the two shared dagger clips at 16x with weight 3 (the "1" / "2" / "Left" / "Right"
	Animation children of the tools were never loaded by their scripts); the exceptions
	are listed by weapon. Clips alternate, first one first.
]]
type Swing = {
	Clips: { string },
	Speed: number,
	Weight: number,
	Looped: boolean?,
}

local function swing(clips: { string }, speed: number, weight: number, looped: boolean?): Swing
	return { Clips = clips, Speed = speed, Weight = weight, Looped = looped }
end

local DAGGER_CLIPS = { AnimationConfig.Dagger1, AnimationConfig.Dagger2 }
-- Clips the legacy scripts built from a bare id (they are not Animation instances of the
-- place, so AnimationConfig does not list them and they load on first use).
local KICK_LEFT = "rbxassetid://129285292341912"
local KICK_RIGHT = "rbxassetid://81712806646228"
local TABLE_KICK = "rbxassetid://118488284509634"
local AIM_CLIP = "rbxassetid://119590650782056"
local SLING_CLIP = "rbxassetid://107432796299459"

local SLOT_SWINGS: { [string]: Swing } = {
	Melee = swing({ AnimationConfig.MeleeR, AnimationConfig.MeleeL }, 1.65, 1),
	Sword = swing(DAGGER_CLIPS, 16, 3),
}

local NO_SWING = swing({}, 1, 1)

local WEAPON_SWINGS: { [string]: Swing } = {
	["Black Leg"] = swing({ KICK_LEFT, KICK_RIGHT }, 16, 3),
	-- The clip loops by itself; the legacy script cut it at its second "EndFrame" marker.
	["Table Kick"] = swing({ TABLE_KICK }, 10, 3, false),

	["Meteorite Sword"] = swing(DAGGER_CLIPS, 10, 3),
	-- Its own clips, at their own speed.
	Bisento = swing({ AnimationConfig.Weapons.Bisento.Left, AnimationConfig.Weapons.Bisento.Right }, 1, 3),
	["Ice Spear"] = swing({ AnimationConfig.Spear1, AnimationConfig.Spear2 }, 1, 3),
	-- The flail's LocalScript played the two axe clips, Looped forced off.
	Flail = swing({ AnimationConfig.Weapons["Divine Axe"].Left, AnimationConfig.Weapons["Divine Axe"].Right }, 16, 3, false),
	-- Its basic attack only lit the blade trails; DD1 is the special's clip.
	["Kanshou and Bakuya"] = NO_SWING,

	Flintlock = swing({ AIM_CLIP }, 16, 3),
	Crossbow = swing({ AIM_CLIP }, 16, 3),
	Stars = swing({ AIM_CLIP }, 16, 3),
	Slingshot = swing({ SLING_CLIP }, 16, 3),
	["Magma Gun"] = swing({ SLING_CLIP }, 16, 3),
}

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

local DataController
local InputController
local AttackService
local HakiService

local localPlayer = Players.LocalPlayer
local lastAttack: { [string]: number } = {}
local dodgeIndex = 0
local DODGE_CLIPS = { AnimationConfig.Dodge1, AnimationConfig.Dodge2, AnimationConfig.Dodge3 }
local swingRight = false

local function getHeldWeapon(): (Tool?, WeaponConfig.WeaponDefinition?)
	local character = localPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(SLOT_ATTRIBUTE) == nil then
		return nil, nil
	end
	return tool, WeaponConfig.Weapons[tool.Name]
end

local function playAnimation(animationId: string?, speed: number, weight: number?, looped: boolean?)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not animationId then
		return
	end

	-- Loaded (and downloaded) ahead of time by AnimationController.
	Animations.Play(animator :: Animator, animationId, {
		Fade = SWING_FADE,
		Weight = weight,
		Speed = speed,
		Looped = looped,
	})
end

local function playSwing(weaponName: string, slot: string)
	local definition = WEAPON_SWINGS[weaponName] or SLOT_SWINGS[slot]
	if not definition then
		-- No legacy script to follow (Bazooka): the first clip of the tool, as it is.
		local clips = (AnimationConfig.Weapons :: any)[weaponName]
		local names: { string } = {}
		for name in clips or {} do
			table.insert(names, name)
		end
		table.sort(names)
		playAnimation(if clips then clips[names[1]] else nil, 1)
		return
	end
	if #definition.Clips == 0 then
		return
	end
	swingRight = not swingRight
	local clip = definition.Clips[if swingRight or #definition.Clips < 2 then 1 else 2]
	playAnimation(clip, definition.Speed, definition.Weight, definition.Looped)
end

-- The swing of a basic attack with `weaponName`; thrown slashes reuse it (WeaponController).
function CombatController:PlaySwing(weaponName: string)
	local weapon = WeaponConfig.Weapons[weaponName]
	if weapon then
		playSwing(weaponName, weapon.Slot)
	end
end

local function attack()
	local tool, weapon = getHeldWeapon()
	if not tool or not weapon or weapon.Slot == "Utility" then
		return
	end

	local definition = AttackConfig.Get(tool.Name, weapon.Slot)
	local cooldown = if AttackConfig.Kicks[tool.Name] then AttackConfig.KickCooldown else definition.Cooldown
	local now = os.clock()
	if now - (lastAttack[weapon.Slot] or 0) < cooldown then
		return
	end
	lastAttack[weapon.Slot] = now

	AttackService.Attack:Fire(InputController:GetAimPosition())

	playSwing(tool.Name, weapon.Slot)
end

function CombatController:KnitInit()
	DataController = Knit.GetController("DataController")
	InputController = Knit.GetController("InputController")
end

function CombatController:KnitStart()
	AttackService = Knit.GetService("AttackService")
	HakiService = Knit.GetService("HakiService")

	-- Observation haki dodged a hit: cycle through the three dodge clips.
	HakiService.Dodged:Connect(function()
		dodgeIndex = dodgeIndex % #DODGE_CLIPS + 1
		playAnimation(DODGE_CLIPS[dodgeIndex], 1)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack()
		end
	end)
	InputController:OnAction("Attack", function(phase: string)
		if phase == "Begin" then
			attack()
		end
	end)

end

return CombatController
