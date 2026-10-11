--!strict
--[[
	Lookups of a service or controller that this place may not load (PlaceManifest).

		local TimeService = Optional.Service("TimeService")
		if TimeService then ... end

	Knit.GetService / Knit.GetController error (or, for a client asking for a service,
	wait forever) when the module is not there. A dependency that is real is simply listed
	in the manifest; this is for the incidental ones: a tool that reports on many systems,
	one branch of a module that touches a system the rest of it does not need. The answer
	comes from the manifest, not from catching the error, so a module that should be
	there and is not still fails loudly.

	Same rules as Knit's own lookups: only after Knit has started (KnitInit or later).
	Server: Service(name) is the service. Client: Service(name) is its remote mirror and
	Controller(name) the controller.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)

local Optional = {}

-- The service, or nil when this place does not load it.
function Optional.Service(name: string): any
	if not PlaceManifest.Has("Services", name) then
		return nil
	end
	return Knit.GetService(name)
end

-- Client only. The controller, or nil when this place does not load it.
function Optional.Controller(name: string): any
	if not PlaceManifest.Has("Controllers", name) then
		return nil
	end
	return (Knit :: any).GetController(name)
end

return table.freeze(Optional)
