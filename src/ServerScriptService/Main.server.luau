--!strict
-- Server entry point. Requires every ModuleScript in Services, then calls Init on all
-- (setup, no cross-service calls) followed by Start on all (begin work).

local ServerScriptService = game:GetService("ServerScriptService")

local servicesFolder = ServerScriptService:WaitForChild("Services")

local services = {}
for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module) :: any
	end
end

for _, service in services do
	if type(service.Init) == "function" then
		service:Init()
	end
end

for _, service in services do
	if type(service.Start) == "function" then
		task.spawn(service.Start, service)
	end
end
