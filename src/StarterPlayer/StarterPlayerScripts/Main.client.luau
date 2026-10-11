--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)

-- Only the controllers of this place (PlaceManifest): one that is not required does not exist.
local controllersFolder = ReplicatedStorage.Client.Controllers
PlaceManifest.Verify("Controllers", PlaceManifest.NamesIn(controllersFolder))
for _, module in PlaceManifest.Modules("Controllers", controllersFolder) do
	(require :: any)(module)
end

Knit.Start()
	:andThen(function()
		-- Studio only: lets test tooling call controllers of the running client.
		if RunService:IsStudio() then
			local bridge = Instance.new("BindableFunction")
			bridge.Name = "DevBridge"
			bridge.OnInvoke = function(controllerName: string, method: string, ...: any): ...any
				local controller = Knit.GetController(controllerName) :: any
				return controller[method](controller, ...)
			end
			bridge.Parent = script.Parent
		end
	end)
	:catch(warn)
