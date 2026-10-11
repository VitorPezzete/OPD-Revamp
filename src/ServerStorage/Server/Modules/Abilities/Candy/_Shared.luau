--!strict
--[[
	Candy fruit - library shared by its abilities. NOT an ability: AbilityService only
	requires modules named after an ability in FruitConfig.

	Touch: the "CandyTouched" debuff, sticky syrup. The legacy control script cloned into
	every character did no damage: 0.25 s after the touch it set the flag that made
	WS_Script multiply the walk speed by 0.1, counted `hits` seconds down and cleared it
	0.25 s later; a new touch restarted the count. Here it is one slow of StatusService
	(10 % speed for floor(hits) + 0.25 s, refreshed by a new touch) plus a replicated
	"CandyTouched" status of the same length for the HUD. Luck owners are immune, as in
	the players' control script.
	Not reproduced: the legacy flag was also cleared when the attacker died.

	Stunned: what Candy has already thrown (ball, pool, wave, hook) kept going in the legacy
	       game when its caster was stunned, so those abilities are KeepThroughStun; they
	       ask here before accepting a press or a release, since AbilityService lets both
	       through for them during a stun.
	Haki:  armament haki doubles Candy damage and usually makes it "Haki" damage.
	Sweep: a wave flying forward, tested as a box against the tracked characters only
	       (see Abilities/Slash/_Shared for the same idea). `onHit` runs once per character.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local TOUCH_STATUS = "CandyTouched"
local TOUCH_SCALE = 0.1
local TOUCH_PADDING = 0.25
local TOUCH_IMMUNE_FRUIT = "Luck"
-- Set by StatusService while any stun is running.
local STUN_STATUS = "Stunned"
local HAKI_MULTIPLIER = 2
local SWEEP_STEP = 0.05

local CandyShared = {}

CandyShared.TouchStatus = TOUCH_STATUS
-- Replicated while Spike Body is on (value: fruit colors).
CandyShared.BodyStatus = "CandyBody"
-- Damage reduction fraction read by DamageModifiers.CandyBody (non-replicated).
CandyShared.GuardStatus = "CandyBodyGuard"

function CandyShared.Touch(ability: any, target: CharacterEntity, hits: number)
	if target.Dead or target == ability.Entity then
		return
	end
	local player = target.Player
	if player and ability.Services.Fruit:HasFruit(player, TOUCH_IMMUNE_FRUIT) then
		return
	end

	local duration = math.max(0, math.floor(hits)) + TOUCH_PADDING
	ability.Services.Status:ApplySlow(target, TOUCH_STATUS, TOUCH_SCALE, duration)
	target:SetStatus(TOUCH_STATUS, true, duration, true)
end

function CandyShared.Stunned(ability: any): boolean
	return ability.Entity:HasStatus(STUN_STATUS)
end

-- (damage multiplier, armament haki on)
function CandyShared.Haki(ability: any): (number, boolean)
	if ability.Services.Haki:IsArmamentActive(ability.Entity) then
		return HAKI_MULTIPLIER, true
	end
	return 1, false
end

function CandyShared.HandPosition(entity: CharacterEntity, left: boolean): Vector3
	local arm = entity.Model:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if arm and arm:IsA("BasePart") then
		return arm.Position
	end
	return entity.Root.Position
end

--[[
	`size`: X width across the flight, Y height, Z depth along it. `direction` is a unit
	vector. Cancelled when ability.Epoch changes (OnInterrupt).
]]
function CandyShared.Sweep(
	ability: any,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	lifetime: number,
	size: Vector3,
	onHit: (target: CharacterEntity) -> ()
)
	local entity: CharacterEntity = ability.Entity
	local epoch = ability.Epoch or 0
	local started = os.clock()
	local travelled = 0
	local hit: { [CharacterEntity]: boolean } = {}

	-- lookAt is undefined for a vertical look vector with the default up axis.
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local orientation = CFrame.lookAt(origin, origin + direction, up)

	local function step()
		if (ability.Epoch or 0) ~= epoch or entity.Dead then
			return
		end

		local elapsed = math.min(os.clock() - started, lifetime)
		local reached = elapsed * speed
		local center = orientation * CFrame.new(0, 0, -(travelled + reached) / 2)
		local box = Vector3.new(size.X, size.Y, reached - travelled + size.Z)
		travelled = reached

		for _, target in Hitbox.Box(center, box, entity) do
			if not hit[target] then
				hit[target] = true
				onHit(target)
			end
		end

		if elapsed < lifetime then
			task.delay(SWEEP_STEP, step)
		end
	end
	step()
end

return CandyShared
