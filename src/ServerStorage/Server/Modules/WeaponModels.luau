--!strict
--[[
	Puts the held model of a weapon inside its Tool (WeaponModelConfig).

	Each mounted part is a child of the Tool, with a Weld from the limb it is held by.
	Nothing is created, moved or destroyed when the weapon is drawn or put away: in the
	Backpack the parts are outside the world and their welds sleep; in the character they
	are welded the moment the Tool arrives, on the server and on every client. They leave
	with the Tool, whatever removes it. The legacy scripts cloned and destroyed the model
	on every equip.

	The parts are never named "Handle" and the Tool keeps no Handle: see WeaponModelConfig.

	A weapon's parts are prepared once (cloned from the assets, made weightless and
	untouchable, scripts and broken joints removed) and copied from that for every Tool.
	A missing model is reported once and the Tool is left as it was.

		WeaponModels.Attach(tool, character?)    before the Tool is handed out
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModelConfig = require(ReplicatedStorage.Shared.Configs.WeaponModelConfig)

type Mount = WeaponModelConfig.Mount
type Prototype = { Part: BasePart, Limb: string }

local WELD_NAME = "WeaponMount"

local WeaponModels = {}

local prototypes: { [string]: { Prototype } | false } = {}

local function findTemplate(mount: Mount): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local weapons = models and models:FindFirstChild("Weapons")
	local folder = weapons and weapons:FindFirstChild(mount.Folder)
	local template = folder and folder:FindFirstChild(mount.Model)
	return if template and template:IsA("BasePart") then template else nil
end

-- A held model must never weigh on, collide with or be hit instead of its holder.
local function soften(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

local function build(mount: Mount): BasePart?
	local template = findTemplate(mount)
	if not template then
		return nil
	end

	local part = template:Clone()
	for _, name in mount.Without or {} do
		local hidden = part:FindFirstChild(name, true)
		if hidden then
			hidden:Destroy()
		end
	end

	local held: { [Instance]: boolean } = { [part] = true }
	soften(part)
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("BasePart") then
			soften(descendant)
		elseif descendant:IsA("LuaSourceContainer") or descendant:IsA("BodyMover") then
			descendant:Destroy()
		elseif descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local joint: any = descendant
			local part0: Instance?, part1: Instance? = joint.Part0, joint.Part1
			local whole = part0 ~= nil
				and part1 ~= nil
				and (part0 == part or part0:IsDescendantOf(part))
				and (part1 == part or part1:IsDescendantOf(part))
			if whole then
				held[part0 :: Instance] = true
				held[part1 :: Instance] = true
			else
				-- Left over from the rig the model was cut from (Aqua Staff, Zombie Head).
				descendant:Destroy()
			end
		end
	end

	-- A part no joint holds would drop out of the hand: it keeps its place in the model.
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("BasePart") and not held[descendant] then
			local fix = Instance.new("WeldConstraint")
			fix.Part0 = part
			fix.Part1 = descendant
			fix.Parent = descendant
		end
	end

	local anchor = if mount.Anchor then part:FindFirstChild(mount.Anchor, true) else nil
	local weld = Instance.new("Weld")
	weld.Name = WELD_NAME
	weld.C0 = mount.Offset
	weld.Part1 = if anchor and anchor:IsA("BasePart") then anchor else part
	weld.Parent = part
	return part
end

local function getPrototypes(weaponName: string): { Prototype }?
	local cached = prototypes[weaponName]
	if cached ~= nil then
		return cached or nil
	end

	local built: { Prototype } = {}
	for _, mount in WeaponModelConfig.Weapons[weaponName] or {} do
		local part = build(mount)
		if part then
			table.insert(built, { Part = part, Limb = mount.Limb })
		else
			warn(`[WeaponModels] No model for "{weaponName}": Assets.Models.Weapons.{mount.Folder}.{mount.Model}`)
		end
	end

	prototypes[weaponName] = if #built > 0 then built else false
	return if #built > 0 then built else nil
end

--[[
	Adds the weapon's model to a freshly cloned Tool. `character` is who will draw it,
	when that is known already: the welds are then ready before the first equip, so the
	model appears with the Tool instead of one round trip later.
]]
function WeaponModels.Attach(tool: Tool, character: Model?)
	local list = getPrototypes(tool.Name)
	if not list then
		return
	end

	local welds: { [Weld]: string } = {}
	for _, prototype in list do
		local part = prototype.Part:Clone()
		local weld = part:FindFirstChild(WELD_NAME)
		if weld and weld:IsA("Weld") then
			welds[weld] = prototype.Limb
		end
		part.Parent = tool
	end

	local function bind(holder: Instance?)
		for weld, limbName in welds do
			local limb = holder and holder:FindFirstChild(limbName)
			weld.Part0 = if limb and limb:IsA("BasePart") then limb else nil
		end
	end
	bind(character)
	-- Drawn by another body than the expected one: hold on to that one. The connection
	-- goes away with the Tool.
	tool.Equipped:Connect(function()
		bind(tool.Parent)
	end)
end

return WeaponModels
