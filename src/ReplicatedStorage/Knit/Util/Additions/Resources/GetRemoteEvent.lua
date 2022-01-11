local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GetFirstChild = require(script.Parent.Parent.Utility.GetFirstChild)

if RunService:IsClient() then
	return function(Name: string): RemoteEvent
		return ReplicatedStorage:WaitForChild("RemoteEvents", math.huge):WaitForChild(Name, math.huge)
	end
else
	return function(Name: string): RemoteEvent
		return GetFirstChild(GetFirstChild(ReplicatedStorage, "Folder", "RemoteEvents"), "RemoteEvent", Name)
	end
end
