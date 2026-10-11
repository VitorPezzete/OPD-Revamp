-- Dev tool: pulls .sync/bundle.json (served on localhost) into the place. Stand-in for the Rojo plugin.
return function()
	local Http = game:GetService("HttpService")
	local bundle = Http:JSONDecode(Http:GetAsync("http://127.0.0.1:48714/bundle.json", true))
	local MERGE = {Assets = true}
	local created, failed = 0, {}
	local function build(node, parent)
		local inst
		local ok, err = pcall(function()
			inst = Instance.new(node.c)
			inst.Name = node.n
			if node.s then inst.Source = node.s end
		end)
		if not ok then table.insert(failed, node.n .. ":" .. node.c .. " " .. tostring(err):sub(1, 60)) return end
		created += 1
		for _, k in node.k or {} do build(k, inst) end
		inst.Parent = parent
	end
	local function mergeFolder(node, parent)
		local existing = parent:FindFirstChild(node.n)
		if not existing then build(node, parent) return end
		for _, k in node.k or {} do
			if k.c == "Folder" then mergeFolder(k, existing) else
				local old = existing:FindFirstChild(k.n)
				if old then old:Destroy() end
				build(k, existing)
			end
		end
	end
	local function syncInto(container, nodes)
		for _, k in nodes do
			if k.c == "StarterPlayerScripts" or k.c == "StarterCharacterScripts" then
				syncInto(container:FindFirstChildOfClass(k.c), k.k or {})
			elseif MERGE[k.n] then
				mergeFolder(k, container)
			else
				local old = container:FindFirstChild(k.n)
				-- Wally packages live inside Shared / Server and are not part of a --no-packages bundle: keep them.
				local packages = old and old:FindFirstChild("Packages")
				if packages then packages.Parent = nil end
				if old then old:Destroy() end
				build(k, container)
				local rebuilt = container:FindFirstChild(k.n)
				if packages and rebuilt and not rebuilt:FindFirstChild("Packages") then packages.Parent = rebuilt end
			end
		end
	end
	for _, svcNode in bundle.k do
		syncInto(game:GetService(svcNode.c), svcNode.k or {})
	end
	return "created=" .. created .. " failed=" .. #failed .. " " .. table.concat(failed, " | ")
end
