--[=[
	@class IKRigBase
]=]

local ArmIKBase = require(script.Parent.Parent.Arm.ArmIKBase)
local BaseObject = require(script.Parent.Parent.Parent.Classes.BaseObject)
local CharacterUtility = require(script.Parent.Parent.Parent.Utility.CharacterUtility)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Parent.Parent.Signal)
local TorsoIKBase = require(script.Parent.Parent.Torso.TorsoIKBase)

local IKRigBase = setmetatable({}, BaseObject)
IKRigBase.ClassName = "IKRigBase"
IKRigBase.__index = IKRigBase

function IKRigBase.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), IKRigBase)
	self.Updating = Signal.new(self.Janitor)

	self.IkTargets = {}
	self.Character = Humanoid.Parent or error("No character")
	self.LastUpdateTime = 0

	return self
end

function IKRigBase:GetLastUpdateTime()
	return self.LastUpdateTime
end

function IKRigBase:GetPlayer()
	return CharacterUtility.GetPlayerFromCharacter(self.Object)
end

function IKRigBase:GetHumanoid()
	return self.Object
end

function IKRigBase:Update()
	self.LastUpdateTime = os.clock()
	self.Updating:Fire()

	for _, Item in ipairs(self.IkTargets) do
		Item:Update()
	end
end

function IKRigBase:UpdateTransformOnly()
	for _, Item in ipairs(self.IkTargets) do
		Item:UpdateTransformOnly()
	end
end

function IKRigBase:PromiseTorso()
	return Promise.Resolve(self:GetTorso())
end

function IKRigBase:GetTorso()
	if not self.Torso then
		self.Torso = self:_GetNewTorso()
	end

	return self.Torso
end

function IKRigBase:PromiseLeftArm()
	return Promise.Resolve(self:GetLeftArm())
end

function IKRigBase:GetLeftArm()
	if not self.LeftArm then
		self.LeftArm = self:_GetNewArm("Left")
	end

	return self.LeftArm
end

function IKRigBase:PromiseRightArm()
	return Promise.Resolve(self:GetRightArm())
end

function IKRigBase:GetRightArm()
	if not self.RightArm then
		self.RightArm = self:_GetNewArm("Right")
	end

	return self.RightArm
end

function IKRigBase:_GetNewArm(ArmName)
	assert(ArmName == "Left" or ArmName == "Right", "Bad armName")
	if self.Object.RigType ~= Enum.HumanoidRigType.R15 then
		return Promise.Reject("Rig is not HumanoidRigType.R15")
	end

	local NewIk = ArmIKBase.new(self.Object, ArmName)
	table.insert(self.IkTargets, NewIk)
	return NewIk
end

function IKRigBase:_GetNewTorso()
	if self.Object.RigType ~= Enum.HumanoidRigType.R15 then
		warn("Rig is not HumanoidRigType.R15")
		return nil
	end

	local NewIk = self.Janitor:Add(TorsoIKBase.new(self.Object), "Destroy")
	table.insert(self.IkTargets, 1, NewIk)
	return NewIk
end

function IKRigBase:__tostring()
	return "IKRigBase"
end

table.freeze(IKRigBase)
return IKRigBase
