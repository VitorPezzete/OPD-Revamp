--!strict
--[[
	Ope fruit - Room (toggle, charged placement).

	The key is always a charge (rate 25, 4-15, i.e. full after 0.6 s) and everything
	happens on its release, as in the legacy game (the client only spoke to the server
	when the key came up):
	- with a Room open: it closes, whatever the charge;
	- released early: the Room opens around the caster one second later (the legacy
	  0.2 s + 0.8 s "mini room in the hand" wind-up);
	- released at full charge: it opens immediately around the aimed point.
	Either way the release plays "OpeRoomCast" (the CreateRoom clip, and the mini room
	spinning in the left hand during the wind-up).

	The Room does nothing by itself: Scalpel, Shambles and Severance only work while
	the caster stands inside it. Size, growth and stamina formulas are in OpeRoom.

	Status "OpeRoom" on the caster:
	"<x>|<y>|<z>|<final radius>|<radius per second>|<server time opened>|<colors>",
	drawn by Effects.Status.OpeRoom (the sphere stays where it was created).

	A stun does not close the Room (KeepThroughStun), as in the legacy game, but a
	stunned caster can neither open nor close it; death, seal and fruit loss close it.

	Legacy problems fixed here:
	- The client sent the charge amount ("hand == 15") that decided where the Room goes.
	- The Room part was resized by a Heartbeat connection per Room on the server, which
	  was never disconnected when the Room was closed before it finished growing.
	- The Room survived the owner being sealed; closing goes through OnInterrupt now.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local OpeRoom = require(script.Parent.OpeRoom)

local STATUS = "OpeRoom"
local STUN_STATUS = "Stunned"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 15
local WIND_UP = 1

local Room = Ability.extend()
-- Legacy accepted aim points this far away.
Room.MaxAimDistance = 5000

Room.KeepThroughStun = true

function Room:CanBegin(): boolean
	local entity = self.Entity
	return not entity:HasStatus(OpeRoom.ProjectingStatus) and not entity:HasStatus(STUN_STATUS)
end

function Room:Open(center: Vector3)
	local entity = self.Entity
	local state = OpeRoom.Open(entity, center, self:GetLevel("Defense"), self:GetAffinity("Defense"))

	self.Active = true
	entity:SetStatus(
		STATUS,
		string.format(
			"%.2f|%.2f|%.2f|%.2f|%.3f|%.3f|%s",
			center.X,
			center.Y,
			center.Z,
			state.FinalRadius,
			state.GrowRate,
			Workspace:GetServerTimeNow(),
			self:GetColorString()
		),
		nil,
		true
	)
end

function Room:OnBegin()
	if self.Pending then
		return
	end
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
end

function Room:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	-- KeepThroughStun keeps the charge alive; a stunned user still cannot finish it.
	if not charge or self.Pending or self.Entity:HasStatus(STUN_STATUS) then
		return
	end
	if self.Active then
		self:OnInterrupt()
		return
	end

	local full = charge >= CHARGE_MAX
	self:PlayEffect("OpeRoomCast", self.Entity.Root.Position, { Mini = not full })
	if full then
		self:Open(input.AimPosition)
		return
	end

	self.Pending = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	task.delay(WIND_UP, function()
		if self.Run ~= run then
			return
		end
		self.Pending = false
		if not self.Entity.Dead then
			self:Open(self.Entity.Root.Position)
		end
	end)
end

function Room:OnInterrupt()
	self.Active = false
	self.Pending = false
	self.ChargeStart = nil
	-- Invalidates a wind-up that has not opened its Room yet.
	self.Run = (self.Run or 0) + 1
	OpeRoom.Close(self.Entity)
	self.Entity:ClearStatus(STATUS)
end

return Room
