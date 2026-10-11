--!strict
--[[
	Helpers shared by the four Quake abilities, which are all charged.

	Only one of them charges at a time (the legacy client refused a press while another
	power was charging or cooling down). The replicated "QuakeCharging" status is that
	lock and also what Effects.Status.QuakeCharging draws:
		"<Punch | Tsunami | Stomp | Seismic>|<R or L>|<bubble scale>|<colors>"
	Each ability remembers the value it wrote (`self.ChargeValue`), so a stray release or
	an interrupt of one never clears the charge of another.

	Release swing: the legacy client played the swing animation on release and, for the
	Tsunami and the Stomp, only told the server once the swing had landed (0.5 s and
	0.2 / 0.25 s later). The server measured the charge up to that message, so the swing
	time counted as charge. Swing plays the animation on the caster (Effects.OneShot.
	QuakeSwing) and the abilities add their own wind-up.

	Charge clock: the legacy server stored the moment the charge began in an IntValue
	(`PowerN.Charge.Value = time()`), which rounds to the nearest whole second, and
	measured the charge from that rounded moment. A release therefore counted up to half
	a second more or less than what was really held (the client's charge bar showed the
	real hold). EndCharge reproduces it: it returns the charge the legacy server would
	have computed and, second, the one the legacy client displayed.

	Stomp lock: for the second after a stomp the legacy client refused to start any other
	Quake power (`CanP3`); STOMP_LOCK_STATUS is that lock.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = {}

Shared.CHARGE_STATUS = "QuakeCharging"
Shared.STOMP_LOCK_STATUS = "QuakeStompLock"
-- Side ("R" / "L") the next one-sided power charges on.
Shared.SIDE_STATUS = "QuakeSide"
Shared.STUN_STATUS = "Stunned"
Shared.HAKI_MULTIPLIER = 2
Shared.CHARGE_TIMEOUT = 60
Shared.SWING_EFFECT = "QuakeSwing"
-- Only the caster's own client plays the swing (the Animator replicates it).
Shared.SWING_RADIUS = 8

-- True when the ability may start charging: nothing else charging, cooldown over.
function Shared.CanCharge(ability: any): boolean
	if os.clock() < (ability.ReadyAt or 0) or ability.Entity:HasStatus(Shared.STOMP_LOCK_STATUS) then
		return false
	end
	-- Pressing again an ability whose release was lost restarts its own charge.
	local current = ability.Entity:GetStatus(Shared.CHARGE_STATUS)
	return current == nil or current == ability.ChargeValue
end

--[[
	Starts the charge. `bubble` is the mesh scale the bubble on the hand grows to over
	three seconds (0 for none). Returns true for the right side.
	The status expires on its own after CHARGE_TIMEOUT so a release that never arrives
	(the legacy game stayed locked until respawn) cannot block the fruit for good.
]]
function Shared.BeginCharge(ability: any, kind: string, bubble: number, fullSeconds: number?): boolean
	-- One side for the whole fruit, as the legacy client's ChargeMode: right first, and
	-- every power but the two-armed Tsunami hands over to the other side.
	local entity = ability.Entity
	local right = entity:GetStatus(Shared.SIDE_STATUS) ~= "L"
	ability.RightSide = right
	if kind ~= "Tsunami" then
		entity:SetStatus(Shared.SIDE_STATUS, if right then "L" else "R")
	end
	ability:BeginCharge(fullSeconds)
	ability.ChargeBegan = time()

	local side = if ability.RightSide then "R" else "L"
	local value = string.format("%s|%s|%.2f|%s", kind, side, bubble, ability:GetColorString())
	ability.ChargeValue = value
	ability.Entity:SetStatus(Shared.CHARGE_STATUS, value, Shared.CHARGE_TIMEOUT, true)
	return ability.RightSide
end

local function clearOwnStatus(ability: any)
	local value = ability.ChargeValue
	ability.ChargeValue = nil
	if value ~= nil and ability.Entity:GetStatus(Shared.CHARGE_STATUS) == value then
		ability.Entity:ClearStatus(Shared.CHARGE_STATUS)
	end
end

--[[
	Ends the charge of this ability (if it was the one charging). Returns nil when nothing
	was charging, otherwise:
	- the charge the legacy server computed, `windup` seconds from now (the swing the
	  legacy client waited for before telling the server), from the rounded start;
	- the charge the legacy client had at the release (real hold, no swing).
]]
function Shared.EndCharge(ability: any, rate: number, minimum: number, maximum: number, windup: number?): (number?, number?)
	local held = ability:EndCharge(rate, minimum, maximum)
	clearOwnStatus(ability)
	local began: number? = ability.ChargeBegan
	ability.ChargeBegan = nil
	if not held or not began then
		return nil, nil
	end
	local elapsed = time() + (windup or 0) - math.round(began)
	return math.floor(math.clamp(elapsed * rate, minimum, maximum)), held
end

-- For OnInterrupt: drops the charge without releasing anything.
function Shared.CancelCharge(ability: any)
	ability.ChargeStart = nil
	ability.ChargeBegan = nil
	clearOwnStatus(ability)
end

-- Release swing of `kind` ("Punch" | "Tsunami" | "Stomp" | "Seismic") on the side that charged.
function Shared.Swing(ability: any, kind: string)
	ability:PlayEffect(Shared.SWING_EFFECT, ability.Entity.Root.Position, {
		Kind = kind,
		Right = ability.RightSide == true,
	}, Shared.SWING_RADIUS)
end

-- Position of a limb of the character, or of its root when the limb is missing.
function Shared.LimbPosition(entity: any, limbName: string): Vector3
	local limb = entity.Model:FindFirstChild(limbName)
	return if limb and limb:IsA("BasePart") then limb.Position else entity.Root.Position
end

--[[
	Looks for a part the legacy game kept in ReplicatedStorage.Resources (Tsunami, Seismic,
	Crack). They are in Assets.Models.Fruits._Shared now; the fruit's own folder and the
	legacy place are still tried, and clients do the same search.
]]
function Shared.FindResource(name: string): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")

	-- A list with holes would stop a loop early: each place is tried explicitly.
	local function search(folder: Instance?): BasePart?
		local found = folder and folder:FindFirstChild(name, true)
		return if found and found:IsA("BasePart") then found else nil
	end

	return search(fruits and fruits:FindFirstChild("Quake"))
		or search(fruits and fruits:FindFirstChild("_Shared"))
		or search(ReplicatedStorage:FindFirstChild("Resources"))
end

return Shared
