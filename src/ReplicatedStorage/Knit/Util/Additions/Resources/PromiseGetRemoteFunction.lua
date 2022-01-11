local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetFirstChild = require(script.Parent.Parent.Utility.GetFirstChild)
local Promise = require(script.Parent.Parent.Parent.Promise)
local PromiseChild = require(script.Parent.Parent.Promises.PromiseChild)

if RunService:IsClient() then
	return function(Name: string)
		return PromiseChild(ReplicatedStorage, "RemoteFunctions", math.huge):Then(function(RemoteFunctions: Folder)
			return PromiseChild(RemoteFunctions, Name, math.huge)
		end)
	end
else
	return function(Name: string)
		return Promise.Resolve(GetFirstChild(GetFirstChild(ReplicatedStorage, "Folder", "RemoteFunctions"), "RemoteFunction", Name))
	end
end
