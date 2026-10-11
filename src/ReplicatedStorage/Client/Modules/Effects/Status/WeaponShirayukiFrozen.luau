--!strict
--[[
	Shirayuki special, on each victim (players and NPC enemies). Status value: true, for
	the 3.3 s between the freeze and the shatter.

	Start: a 5x7x5 block of glass around the body and twelve ice crystals rising in a
	ring 6 studs around it (0.4 s); then fifteen thin slashes of light, one every 0.1 s,
	at random angles through the body.
	End (status removed): the ice goes, a white ring spreads to 45 studs and twenty
	shards fly off. Legacy sounds: freeze on start, shatter on end.
]]
local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local ICE = Color3.fromRGB(220, 240, 255)
local PALE = Color3.fromRGB(200, 230, 255)
local SLASH = Color3.fromRGB(200, 240, 255)
local FREEZE_SOUND = "rbxassetid://260433557"
local SHATTER_SOUND = "rbxassetid://7013638068"

local function noop() end

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return noop
	end

	local alive = true
	local ice: { Instance } = {}
	WeaponFx.Sound(FREEZE_SOUND, root, 1)

	table.insert(ice, WeaponFx.Part({ Size = Vector3.new(5, 7, 5), Material = Enum.Material.Glass, Color = ICE, Transparency = 0.3, CFrame = root.CFrame }))
	for index = 1, 12 do
		local angle = index / 12 * math.pi * 2
		local base = root.Position + Vector3.new(math.cos(angle) * 6, -4, math.sin(angle) * 6)
		local crystal = Instance.new("WedgePart")
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.CanQuery = false
		crystal.CanTouch = false
		crystal.Size = Vector3.zero
		crystal.Material = if index % 2 == 0 then Enum.Material.Glass else Enum.Material.Ice
		crystal.Color = PALE
		crystal.Transparency = 0.1
		crystal.CFrame = CFrame.new(base)
		crystal.Parent = workspace
		WeaponFx.Tween(crystal, 0.4, {
			Size = Vector3.new(math.random(2, 5), math.random(10, 18), math.random(2, 5)),
			CFrame = CFrame.lookAt(base, root.Position + Vector3.new(0, math.random(2, 6), 0)) * CFrame.Angles(math.rad(90), 0, 0),
		}, Enum.EasingStyle.Back)
		table.insert(ice, crystal)
	end

	task.spawn(function()
		for _ = 1, 15 do
			if not alive or root.Parent == nil then
				return
			end
			local angles = CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)))
			local length = math.random(30, 50)
			local slash = WeaponFx.Part({
				Size = Vector3.new(0.2, 0.2, length),
				Material = Enum.Material.Neon,
				Color = SLASH,
				CFrame = root.CFrame * angles * CFrame.new(0, 0, math.random(-5, 5)),
			}, 0.25)
			WeaponFx.Tween(slash, 0.2, {
				Size = Vector3.new(0.01, 0.01, length + 30),
				CFrame = slash.CFrame * CFrame.Angles(0, math.rad(math.random(-20, 20)), 0),
				Transparency = 1,
			})
			task.wait(0.1)
		end
	end)

	return function()
		alive = false
		for _, part in ice do
			part:Destroy()
		end
		if root.Parent == nil then
			return
		end

		local position = root.Position
		WeaponFx.Sound(SHATTER_SOUND, root, 2)
		local ring = WeaponFx.Part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 0.1, 0.1),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 255, 255),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		}, 0.4)
		WeaponFx.Tween(ring, 0.4, { Size = Vector3.new(0.5, 45, 45), Transparency = 1 })

		for index = 1, 20 do
			local shard = Instance.new("WedgePart")
			shard.Size = Vector3.new(math.random(1, 4), math.random(3, 8), math.random(1, 4))
			shard.Material = if index % 2 == 0 then Enum.Material.Glass else Enum.Material.Ice
			shard.Color = ICE
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.Massless = true
			shard.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)))
			shard.Parent = workspace
			shard.AssemblyLinearVelocity = Vector3.new(math.random(-60, 60), math.random(30, 80), math.random(-60, 60))
			shard.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
			WeaponFx.Tween(shard, 2, { Size = Vector3.zero, Transparency = 1 }, Enum.EasingStyle.Linear)
			game:GetService("Debris"):AddItem(shard, 2.2)
		end
	end
end
