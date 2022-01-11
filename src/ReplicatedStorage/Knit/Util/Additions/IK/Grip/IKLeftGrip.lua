--[=[
	Left grip
	@class IKLeftGrip
]=]

local IKGripBase = require(script.Parent.IKGripBase)

local IKLeftGrip = setmetatable({}, IKGripBase)
IKLeftGrip.ClassName = "IKLeftGrip"
IKLeftGrip.__index = IKLeftGrip

function IKLeftGrip.new(ObjectValue: ObjectValue)
	local self = setmetatable(IKGripBase.new(ObjectValue), IKLeftGrip)

	self:PromiseIKRig():Then(function(IkRig)
		return self.Janitor:AddPromise(IkRig:PromiseLeftArm())
	end):Then(function(LeftArm)
		self.Janitor:Add(LeftArm:Grip(self:GetAttachment(), self:GetPriority()), true)
	end)

	return self
end

function IKLeftGrip:__tostring()
	return "IKLeftGrip"
end

table.freeze(IKLeftGrip)
return IKLeftGrip
