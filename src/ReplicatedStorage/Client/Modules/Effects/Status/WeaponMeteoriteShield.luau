--!strict
--[[
	Meteorite Sword special: the meteorite shell around the user for the 2 s the shield
	lasts. It also goes as soon as the shield is broken (the "Shield" attribute of the
	character reaching 0), as the legacy script did.
	Template: "MeteoriteShield" (legacy ServerStorage.OtherStuff.SwordSlashes), welded to
	the root; a dark force-field ball without it. Status value: true.
]]
local WeaponFx = require(script.Parent.Parent.Util.WeaponFx)

local function noop() end

return function(character: Model, _value: any, _isLocal: boolean): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return noop
	end

	local template = WeaponFx.FindAsset("MeteoriteShield")
	local shield: BasePart
	if template and template:IsA("BasePart") then
		shield = template:Clone() :: BasePart
		WeaponFx.Neutralize(shield)
	else
		shield = WeaponFx.Part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(11, 11, 11),
			Material = Enum.Material.ForceField,
			Color = Color3.fromRGB(90, 70, 60),
		})
	end
	shield.Anchored = false
	shield.Massless = true
	shield.CFrame = root.CFrame

	local weld = Instance.new("Weld")
	weld.Part0 = shield
	weld.Part1 = root
	weld.Parent = shield
	shield.Parent = root

	local connection = character:GetAttributeChangedSignal("Shield"):Connect(function()
		local left = character:GetAttribute("Shield")
		if type(left) == "number" and left <= 0 then
			shield:Destroy()
		end
	end)

	return function()
		connection:Disconnect()
		shield:Destroy()
	end
end
