--!strict
--[[
	Chilly fruit - Ice Path (toggle): run faster on a road of ice laid under the feet,
	tilted towards the aim point so it can climb or descend.

	- Speed bonus (fraction of base walk speed): (2 + melee affinity) * (melee level / cap).
	- Every 0.1 s a slab is laid under the character and lasts 1 s. Slab size =
	  template size * melee level / 150 * melee affinity.

	The slab is the legacy ice chunk, ReplicatedStorage.Assets.Models.Fruits._Shared.
	ChillyPath (a union, Foil): it is cloned, never rebuilt from a plain part. First fruit
	color when the fruit has one, the template's own color otherwise.

	The slabs are the one thing here other players can stand on, so they are real server
	parts: ten clones per user, made as the path starts, recycled in a ring (the oldest
	slab is moved to the new spot, which is exactly the 1 s lifetime at one slab per
	0.1 s) and destroyed in OnInterrupt. Everyone but the owner sees and walks on these.
	The owner rides slabs its own client lays under its feet the moment it moves
	(Effects.Status.ChillyPath, as the legacy LocalScript did) and hides these ones for
	itself, so it never waits for the server and never sees two overlapping roads.

	Aim. The legacy client chose each slab's CFrame and the server cloned a part there
	(any CFrame, anywhere). The position now always comes from the server's own root
	position; only the tilt uses the aim point, refreshed by the owner's client through
	phase 3 inputs (Effects.Status.ChillyPath -> OnAction), validated by AbilityService.

	Legacy problems fixed here:
	- The speed flag was only cleared by a "stop" message from the client, with a
	  task.delay(1.5) fallback comparing timestamps; a dead or sealed user kept the bonus.
	- Client and server each created a slab for every step, and the owner saw both (two
	  overlapping parts).

	The tick is not capped in time (the legacy toggle was not either); it stops as soon
	as the ability is toggled off or interrupted.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local Ability = require(ServerStorage.Server.Classes.Ability)
local World = require(ReplicatedStorage.Shared.Util.World)

local STATUS = "ChillyPath"
local SPEED_MODIFIER = "ChillyPath"

local TICK = 0.1
local SLAB_COUNT = 10
local TEMPLATE_PATH = { "Models", "Fruits", "_Shared", "ChillyPath" }
-- Stand-in used only when the template is missing: its size, material and color.
local FALLBACK_SIZE = Vector3.new(9.4, 1, 8.6)
local FALLBACK_COLOR = Color3.fromRGB(128, 187, 219)
local LEVEL_DIVISOR = 150
-- Root to sole distance of the R6 character.
local FEET_OFFSET = 3

local IcePath = Ability.extend()

local function findTemplate(): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in TEMPLATE_PATH do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current else nil
end

local function createSlab(template: BasePart?, scale: number, color: Color3?, folder: Instance): BasePart
	local slab: BasePart
	if template then
		slab = template:Clone()
		for _, descendant in slab:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		slab.Size = template.Size * scale
	else
		local plain = Instance.new("Part")
		plain.Material = Enum.Material.Foil
		plain.Color = FALLBACK_COLOR
		plain.TopSurface = Enum.SurfaceType.Smooth
		plain.BottomSurface = Enum.SurfaceType.Smooth
		plain.Size = FALLBACK_SIZE * scale
		slab = plain
	end
	slab.Name = "ChillyPath"
	slab.Anchored = true
	slab.CanCollide = true
	slab.CanTouch = false
	slab.CastShadow = false
	if color then
		slab.Color = color
	end
	slab.Parent = folder
	return slab
end

local function placeSlab(self: any)
	local slabs: { BasePart } = self.Slabs
	local folder: Instance? = self.Folder
	if not folder then
		return
	end

	local index = self.NextSlab
	local slab = slabs[index]
	if not slab then
		slab = createSlab(self.Template, self.SlabScale, self.SlabColor, folder)
		slabs[index] = slab
	end
	self.NextSlab = index % SLAB_COUNT + 1

	local position = self.Entity.Root.Position - Vector3.new(0, FEET_OFFSET + slab.Size.Y / 2, 0)

	local toAim = (self.Aim :: Vector3) - position
	if toAim.Magnitude < 1 or math.abs(toAim.Unit.Y) > 0.99 then
		-- Aiming at the slab itself or straight up / down: lay it flat.
		local look = self.Entity.Root.CFrame.LookVector
		toAim = Vector3.new(look.X, 0, look.Z)
		if toAim.Magnitude < 0.05 then
			toAim = Vector3.new(0, 0, -1)
		end
	end
	slab.CFrame = CFrame.lookAt(position, position + toAim) * CFrame.Angles(0, math.rad(math.random(1, 360)), 0)
end

function IcePath:OnBegin(input: Ability.AbilityInput)
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	local affinity = self:GetAffinity("Melee")

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local scale = self:GetLevel("Melee") / LEVEL_DIVISOR * affinity
	local colors = self:GetColorString()

	self.Aim = input.AimPosition
	self.Template = findTemplate()
	self.SlabScale = scale
	self.SlabColor = FruitColor.Parse(colors)
	self.Slabs = {}
	self.NextSlab = 1

	-- One folder per user so the owner's client can keep its aim ray off its own road.
	local folder = Instance.new("Folder")
	folder.Name = `ChillyPath_{self.Player.UserId}`
	folder.Parent = World.Abilities()
	self.Folder = folder

	entity:SetSpeedBonus(SPEED_MODIFIER, (2 + affinity) * self:GetLevelScale("Melee"))
	-- "<fruit slot>;<ability slot>;<slab scale>;<colors>": the owner's client needs the
	-- slots to send its aim and the rest to lay the same slabs under its own feet.
	local context = self.Context
	local value = string.format("%d;%d;%.3f;%s", context.FruitSlot, context.Definition.Slot, scale, colors)
	entity:SetStatus(STATUS, value, nil, true)

	local function step()
		if self.Run ~= run or not self.Active then
			return
		end
		placeSlab(self)
		task.delay(TICK, step)
	end
	step()
end

-- Aim refresh from the owner's client. Only stored: the tick decides when slabs appear.
function IcePath:OnAction(input: Ability.AbilityInput)
	self.Aim = input.AimPosition
end

function IcePath:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	self.Entity:ClearStatus(STATUS)

	local folder: Instance? = self.Folder
	if folder then
		folder:Destroy()
		self.Folder = nil
	end
	self.Slabs = {}
	self.Template = nil
end

return IcePath
