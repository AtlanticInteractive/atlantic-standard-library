--[=[
	Right grip
	@class IKRightGrip
]=]

local IKGripBase = require(script.Parent.IKGripBase)

local IKRightGrip = setmetatable({}, IKGripBase)
IKRightGrip.ClassName = "IKRightGrip"
IKRightGrip.__index = IKRightGrip

function IKRightGrip.new(ObjectValue: ObjectValue)
	local self = setmetatable(IKGripBase.new(ObjectValue), IKRightGrip)

	self:PromiseIKRig():Then(function(IkRig)
		return self.Janitor:AddPromise(IkRig:PromiseRightArm())
	end):Then(function(RightArm)
		self.Janitor:Add(RightArm:Grip(self:GetAttachment(), self:GetPriority()), true)
	end)

	return self
end

function IKRightGrip:__tostring()
	return "IKRightGrip"
end

table.freeze(IKRightGrip)
return IKRightGrip
