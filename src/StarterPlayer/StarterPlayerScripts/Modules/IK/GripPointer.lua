--[=[
	Simple rig component to point at attachments given

	@client
	@class GripPointer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)

local GripPointer = setmetatable({}, BaseObject)
GripPointer.ClassName = "GripPointer"
GripPointer.__index = GripPointer

function GripPointer.new(IkRig)
	local self = setmetatable(BaseObject.new(), GripPointer)
	self.IkRig = IkRig or error("No ikRig")
	return self
end

function GripPointer:SetLeftGrip(LeftGrip)
	self.LeftGripAttachment = LeftGrip
	if not self.LeftGripAttachment then
		return self.Janitor:Remove("LeftGripJanitor")
	end

	local LeftGripJanitor = self.Janitor:Add(Janitor.new(), "Destroy", "LeftGripJanitor")
	LeftGripJanitor:AddPromise(self.IkRig:PromiseLeftArm()):Then(function(LeftArm)
		LeftGripJanitor:Add(LeftArm:Grip(self.LeftGripAttachment, 1), true)
	end)
end

function GripPointer:SetRightGrip(RightGrip)
	self.RightGripAttachment = RightGrip
	if not self.RightGripAttachment then
		return self.Janitor:Remove("RightGripJanitor")
	end

	local RightGripJanitor = self.Janitor:Add(Janitor.new(), "Destroy", "RightGripJanitor")
	RightGripJanitor:AddPromise(self.IkRig:PromiseRightArm()):Then(function(RightArm)
		RightGripJanitor:Add(RightArm:Grip(self.RightGripAttachment, 1), true)
	end)
end

function GripPointer:__tostring()
	return "GripPointer"
end

table.freeze(GripPointer)
return GripPointer
