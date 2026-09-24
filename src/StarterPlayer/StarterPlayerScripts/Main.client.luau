--!strict
-- Client entry point. Requires every ModuleScript in Controllers, then calls Init on all
-- followed by Start on all. Controllers handle UI and visuals only; the server decides everything.

local controllersFolder = script.Parent:WaitForChild("Controllers")

local controllers = {}
for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module) :: any
	end
end

for _, controller in controllers do
	if type(controller.Init) == "function" then
		controller:Init()
	end
end

for _, controller in controllers do
	if type(controller.Start) == "function" then
		task.spawn(controller.Start, controller)
	end
end
