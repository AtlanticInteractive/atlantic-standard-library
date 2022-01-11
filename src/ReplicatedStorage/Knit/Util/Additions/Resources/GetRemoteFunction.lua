local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GetFirstChild = require(script.Parent.Parent.Utility.GetFirstChild)

if RunService:IsClient() then
	return function(Name: string): RemoteFunction
		return ReplicatedStorage:WaitForChild("RemoteFunctions", math.huge):WaitForChild(Name, math.huge)
	end
else
	return function(Name: string): RemoteFunction
		return GetFirstChild(GetFirstChild(ReplicatedStorage, "Folder", "RemoteFunctions"), "RemoteFunction", Name)
	end
end
