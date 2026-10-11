--!strict
--[[
	Chilly fruit - Ice Path, on the owner's client.
	Status value: "<fruit slot>;<ability slot>;<slab scale>;<fruit colors>".

	The road everyone else sees and walks on is made of server parts (Abilities.Chilly
	"Ice Path"), laid where the server knows the character to be: a moment behind its
	owner. So, as the legacy LocalScript did, the owner's client lays its own slabs: one
	every 0.1 s under the feet, tilted towards the point the mouse is on and turned at
	random, kept for 1 s.
	Template: ReplicatedStorage.Assets.Models.Fruits._Shared.ChillyPath (a union), scaled
	by the slab scale; first fruit color when the fruit has one. Ten clones are recycled
	in a ring (the oldest becomes the newest).
	The owner's own server slabs are hidden and made non-solid on this client, so only one
	road is seen and felt. Without the template none of this happens and the owner rides
	the server slabs like everyone else.

	The client also tells the server where it is aiming, about three times a second, as
	phase 3 inputs: the server tilts its next slabs towards that point.

	The aim ray ignores the character and both sets of slabs (they sit right under the
	feet and would otherwise always be what the mouse points at when looking down). The
	legacy client did the same with Mouse.TargetFilter.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- Two such streams (a Chilly + Snow user) must fit the server input budget (8 per second).
local SEND_INTERVAL = 0.35
-- Stays inside AbilityConfig.MaxAimDistance even with the camera far behind.
local AIM_RANGE = 800

local SLAB_INTERVAL = 0.1
local SLAB_LIFE = 1
local SLAB_COUNT = 10
-- Root to sole distance of the R6 character.
local FEET_OFFSET = 3

local function noop() end

local function hide(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CanCollide = false
		instance.LocalTransparencyModifier = 1
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	if not fruitSlot or not abilitySlot then
		return noop
	end
	local scale = tonumber(fields[3]) or 1
	local color = FruitColor.Parse(fields[4] or "")

	local abilityService = Knit.GetService("AbilityService")
	local folderName = `ChillyPath_{Players.LocalPlayer.UserId}`

	local foundTemplate = EffectAssets.Find("Models", "Fruits", "_Shared", "ChillyPath")
	local template: BasePart? = if foundTemplate and foundTemplate:IsA("BasePart") then foundTemplate else nil

	local localFolder: Folder? = nil
	if template then
		local created = Instance.new("Folder")
		created.Name = "ChillyPathLocal"
		created.Parent = World.Abilities()
		localFolder = created
	end

	local slabs: { BasePart } = {}
	local nextSlab = 1
	local watched: Instance? = nil
	local watchConnection: RBXScriptConnection? = nil
	local active = true

	local function lay(root: BasePart, aim: Vector3)
		local folder = localFolder
		if not template or not folder then
			return
		end

		local slab = slabs[nextSlab]
		if not slab then
			slab = template:Clone()
			for _, descendant in slab:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy()
				end
			end
			slab.Size = template.Size * scale
			slab.Anchored = true
			slab.CanCollide = true
			slab.CanTouch = false
			slab.CastShadow = false
			if color then
				slab.Color = color
			end
			slab.Parent = folder
			slabs[nextSlab] = slab
		end
		nextSlab = nextSlab % SLAB_COUNT + 1

		local position = root.Position - Vector3.new(0, FEET_OFFSET + slab.Size.Y / 2, 0)
		local toAim = aim - position
		if toAim.Magnitude < 1 or math.abs(toAim.Unit.Y) > 0.99 then
			-- Aiming at the slab itself or straight up / down: lay it flat.
			local look = root.CFrame.LookVector
			toAim = Vector3.new(look.X, 0, look.Z)
			if toAim.Magnitude < 0.05 then
				toAim = Vector3.new(0, 0, -1)
			end
		end
		slab.CFrame = CFrame.lookAt(position, position + toAim) * CFrame.Angles(0, math.rad(math.random(1, 360)), 0)
	end

	task.spawn(function()
		local lastSent = 0
		while active do
			local camera = Workspace.CurrentCamera
			local root = character:FindFirstChild("HumanoidRootPart")
			if camera and root and root:IsA("BasePart") then
				local serverSlabs = World.Abilities():FindFirstChild(folderName)
				if localFolder and serverSlabs ~= watched then
					if watchConnection then
						watchConnection:Disconnect()
						watchConnection = nil
					end
					watched = serverSlabs
					if serverSlabs then
						for _, child in serverSlabs:GetChildren() do
							hide(child)
						end
						watchConnection = serverSlabs.ChildAdded:Connect(hide)
					end
				end

				local filter: { Instance } = { character }
				if serverSlabs then
					table.insert(filter, serverSlabs)
				end
				if localFolder then
					table.insert(filter, localFolder)
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = filter

				local mouse = UserInputService:GetMouseLocation()
				local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
				local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
				local aim = if result then result.Position else ray.Origin + ray.Direction * AIM_RANGE

				lay(root, aim)

				local now = os.clock()
				if now - lastSent >= SEND_INTERVAL then
					lastSent = now
					abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)
				end
			end
			task.wait(SLAB_INTERVAL)
		end
	end)

	return function()
		active = false
		if watchConnection then
			watchConnection:Disconnect()
		end
		-- The last slabs melt on their own time, as each legacy slab did.
		if localFolder then
			Debris:AddItem(localFolder, SLAB_LIFE)
		end
	end
end
