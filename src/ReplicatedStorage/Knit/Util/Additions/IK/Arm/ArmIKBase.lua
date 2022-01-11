--[=[
	Provides IK for a given arm
	@class ArmIKBase
]=]

local BaseObject = require(script.Parent.Parent.Parent.Classes.BaseObject)
local Constants = require(script.Parent.Parent.Parent.KnitConstants)
local IKAimPositionPriorities = require(script.Parent.IKAimPositionPriorities)
local IKResource = require(script.Parent.Parent.Resources.IKResource)
local IKResourceUtility = require(script.Parent.Parent.Resources.IKResourceUtility)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Math = require(script.Parent.Parent.Parent.Math.Math)

local CFA_90X = CFrame.Angles(math.pi / 2, 0, 0)
local RagdollConstants = Constants.RAGDOLL_CONSTANTS

local ArmIKBase = setmetatable({}, BaseObject)
ArmIKBase.ClassName = "ArmIKBase"
ArmIKBase.__index = ArmIKBase

function ArmIKBase.new(Humanoid: Humanoid, ArmName: string)
	local self = setmetatable(BaseObject.new(), ArmIKBase)
	self.Humanoid = Humanoid or error("No humanoid")
	self.Grips = {}
	self.Resources = self.Janitor:Add(IKResource.new(IKResourceUtility.CreateResource({
		Name = "Character";
		RobloxName = self.Humanoid.Parent.Name;
		Children = {
			IKResourceUtility.CreateResource({
				Name = "UpperArm";
				RobloxName = ArmName .. "UpperArm";
				Children = {
					IKResourceUtility.CreateResource({
						Name = "Shoulder";
						RobloxName = ArmName .. "Shoulder";
					});
				};
			});

			IKResourceUtility.CreateResource({
				Name = "LowerArm";
				RobloxName = ArmName .. "LowerArm";
				Children = {
					IKResourceUtility.CreateResource({
						Name = "Elbow";
						RobloxName = ArmName .. "Elbow";
					});
				};
			});

			IKResourceUtility.CreateResource({
				Name = "Hand";
				RobloxName = ArmName .. "Hand";
				Children = {
					IKResourceUtility.CreateResource({
						Name = "Wrist";
						RobloxName = ArmName .. "Wrist";
					});

					IKResourceUtility.CreateResource({
						Name = "HandGripAttachment";
						RobloxName = ArmName .. "GripAttachment";
					});
				};
			});
		};
	})), "Destroy")

	self.Resources:SetInstance(self.Humanoid.Parent or error("No humanoid.Parent"))
	self.Gripping = self.Janitor:Add(Instance.new("BoolValue"), "Destroy")

	self.Janitor:Add(self.Gripping.Changed:Connect(function()
		self:_UpdateMotorsEnabled()
	end), "Disconnect")

	self:_UpdateMotorsEnabled()
	return self
end

function ArmIKBase:Grip(Attachment, Priority)
	local GripData = {
		Attachment = Attachment;
		Priority = Priority or IKAimPositionPriorities.DEFAULT;
	}

	local Index = 1
	while self.Grips[Index] and self.Grips[Index].priority > Priority do
		Index += 1
	end

	table.insert(self.Grips, Index, GripData)
	self.Gripping.Value = true

	return function()
		if self.Destroy then
			self:_StopGrip(GripData)
		end
	end
end

function ArmIKBase:_StopGrip(Grip)
	for Index, Value in ipairs(self.Grips) do
		if Value == Grip then
			table.remove(self.Grips, Index)
			break
		end
	end

	if not next(self.Grips) then
		self.Gripping.Value = false
	end
end

-- Sets transform
function ArmIKBase:UpdateTransformOnly()
	if not self.Grips[1] or not self.ShoulderTransform or not self.ElbowTransform or not self.Resources.Ready.Value then
		return
	end

	self.Resources:Get("Shoulder").Transform = self.ShoulderTransform
	self.Resources:Get("Elbow").Transform = self.ElbowTransform
end

function ArmIKBase:Update()
	if self:_UpdatePoint() then
		local ShoulderXAngle = self.ShoulderXAngle
		local ElbowXAngle = self.ElbowXAngle

		self.ShoulderTransform = CFrame.new(Vector3.new(), self.Offset) * CFA_90X * CFrame.Angles(ShoulderXAngle, 0, 0)
		self.ElbowTransform = CFrame.Angles(ElbowXAngle, 0, 0)

		self:UpdateTransformOnly()
	end
end

function ArmIKBase:_UpdatePoint()
	local Grip = self.Grips[1]
	if not Grip then
		self:_Clear()
		return false
	end

	if not self:_CalculatePoint(Grip.Attachment.WorldPosition) then
		self:_Clear()
		return false
	end

	return true
end

function ArmIKBase:_Clear()
	self.Offset = nil
	self.ElbowTransform = nil
	self.ShoulderTransform = nil
end

function ArmIKBase:_CalculatePoint(TargetPositionWorld)
	if not self.Resources.Ready.Value then
		return false
	end

	local Shoulder = self.Resources:Get("Shoulder")
	local Elbow = self.Resources:Get("Elbow")
	local Wrist = self.Resources:Get("Wrist")
	local GripAttachment = self.Resources:Get("HandGripAttachment")
	if not (Shoulder.Part0 and Elbow.Part0 and Elbow.Part1) then
		return false
	end

	local Base = Shoulder.Part0.CFrame * Shoulder.C0
	local ElbowCFrame = Elbow.Part0.CFrame * Elbow.C0
	local WristCFrame = Elbow.Part1.CFrame * Wrist.C0

	local R0 = (Base.Position - ElbowCFrame.Position).Magnitude
	local R1 = (ElbowCFrame.Position - WristCFrame.Position).Magnitude

	R1 += (GripAttachment.WorldPosition - WristCFrame.Position).Magnitude

	local Offset = Base:PointToObjectSpace(TargetPositionWorld)
	local D = Offset.Magnitude

	if D > R0 + R1 then -- Case: Circles are seperate
		D = R0 + R1
	end

	if D == 0 then
		return false
	end

	local BaseAngle = Math.LawOfCosines(R0, D, R1)
	local ElbowAngle = Math.LawOfCosines(R1, R0, D) -- Solve for angle across from d

	if not (BaseAngle and ElbowAngle) then
		return false
	end

	ElbowAngle -= math.pi
	if ElbowAngle > -math.pi / 32 then -- Force a bit of bent elbow
		ElbowAngle = -math.pi / 32
	end

	self.ShoulderXAngle = -BaseAngle
	self.ElbowXAngle = -ElbowAngle
	self.Offset = Offset.Unit * D
	return true
end

function ArmIKBase:_UpdateMotorsEnabled()
	self.Janitor:Remove("GripJanitor")
	if not self.Gripping.Value then
		return
	end

	local GripJanitor = self.Janitor:Add(Janitor.new(), "Destroy", "GripJanitor")
	GripJanitor:Add(self.Resources.ReadyChanged:Connect(function()
		GripJanitor:Add(self:_SetAttributes(), "Destroy", "Attributes")
	end), "Disconnect")

	GripJanitor:Add(self:_SetAttributes(), "Destroy", "Attributes")
end

function ArmIKBase:_SetAttributes()
	if not self.Resources.Ready.Value then
		return nil
	end

	local Attributes = Janitor.new()

	local Shoulder = self.Resources:Get("Shoulder")
	local Elbow = self.Resources:Get("Elbow")
	local Wrist = self.Resources:Get("Wrist")

	Shoulder:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME, true)
	Elbow:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME, true)
	Wrist:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME, true)

	Attributes:Add(function()
		Shoulder:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME, false)
		Elbow:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME, false)
		Wrist:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME, false)
	end, true)

	return Attributes
end

function ArmIKBase:__tostring()
	return "ArmIKBase"
end

table.freeze(ArmIKBase)
return ArmIKBase
