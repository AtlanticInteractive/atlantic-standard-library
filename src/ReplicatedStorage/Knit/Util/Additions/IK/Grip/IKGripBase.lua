--[=[
	Meant to be used with a binder
	@class IKGripBase
]=]

local RunService = game:GetService("RunService")

local BaseObject = require(script.Parent.Parent.Parent.Classes.BaseObject)
local GetController = require(script.Parent.Parent.Parent.Parent.GetController)
local GetService = require(script.Parent.Parent.Parent.Parent.GetService)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)
local PromisePropertyValue = require(script.Parent.Parent.Parent.Promises.PromisePropertyValue)

local IKGripBase = setmetatable({}, BaseObject)
IKGripBase.ClassName = "IKGripBase"
IKGripBase.__index = IKGripBase

function IKGripBase.new(ObjectValue: ObjectValue)
	local self = setmetatable(BaseObject.new(ObjectValue), IKGripBase)
	self.Attachment = self.Object.Parent
	assert(self.Object:IsA("ObjectValue"), "Not an object value")
	assert(self.Attachment:IsA("Attachment"), "Not parented to an attachment")
	return self
end

function IKGripBase:GetPriority()
	return 1
end

function IKGripBase:GetAttachment()
	return self.Object.Parent
end

function IKGripBase:PromiseIKRig()
	if self.IkRigPromise then
		return self.IkRigPromise
	end

	local IKService
	if RunService:IsServer() then
		IKService = GetService("IKService")
	else
		IKService = GetController("IKController")
	end

	local PropertyPromise = self.Janitor:Add(PromisePropertyValue(self.Object, "Value"), "Cancel")
	self.IkRigPromise = PropertyPromise:Then(function(Humanoid)
		if not Humanoid:IsA("Humanoid") then
			warn("[IKGripBase.PromiseIKRig] - Humanoid in link is not a humanoid")
			return Promise.Reject()
		end

		return self.Janitor:AddPromise(IKService:PromiseRig(Humanoid))
	end)

	return self.IkRigPromise
end

function IKGripBase:__tostring()
	return "IKGripBase"
end

table.freeze(IKGripBase)
return IKGripBase
