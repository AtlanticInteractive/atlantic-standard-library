--[=[
	Torso resources for IK
	@class TorsoIKBase
]=]

local AccelTween = require(script.Parent.Parent.Parent.Physics.AccelTween)
local BaseObject = require(script.Parent.Parent.Parent.Classes.BaseObject)
local IKResource = require(script.Parent.Parent.Resources.IKResource)
local IKResourceUtility = require(script.Parent.Parent.Resources.IKResourceUtility)
--local Option = require(script.Parent.Parent.Parent.Parent.Option)
local Signal = require(script.Parent.Parent.Parent.Parent.Signal)
local TorsoIKUtility = require(script.Parent.TorsoIKUtility)

--type Option<Value> = Option.Option<Value>

local TorsoIKBase = setmetatable({}, BaseObject)
TorsoIKBase.ClassName = "TorsoIKBase"
TorsoIKBase.__index = TorsoIKBase

function TorsoIKBase.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(), TorsoIKBase)
	self.Humanoid = Humanoid or error("No humanoid")
	self.Pointed = Signal.new(self.Janitor) -- :Fire(position | nil)

	self.Resources = self.Janitor:Add(IKResource.new(IKResourceUtility.CreateResource({
		Name = "Character";
		RobloxName = self.Humanoid.Parent.Name;
		Children = {
			IKResourceUtility.CreateResource({
				Name = "RootPart";
				RobloxName = "HumanoidRootPart";
			});

			IKResourceUtility.CreateResource({
				Name = "LowerTorso";
				RobloxName = "LowerTorso";
			});

			IKResourceUtility.CreateResource({
				Name = "UpperTorso";
				RobloxName = "UpperTorso";
				Children = {
					IKResourceUtility.CreateResource({
						Name = "Waist";
						RobloxName = "Waist";
					});
				};
			});

			IKResourceUtility.CreateResource({
				Name = "Head";
				RobloxName = "Head";
				Children = {
					IKResourceUtility.CreateResource({
						Name = "Neck";
						RobloxName = "Neck";
					});
				};
			});
		};
	})), "Destroy")

	self.Resources:SetInstance(self.Humanoid.Parent or error("No humanoid.Parent"))

	self.WaistY = AccelTween.new(20)
	self.WaistZ = AccelTween.new(15)

	self.HeadY = AccelTween.new(30)
	self.HeadZ = AccelTween.new(20)

	self.Janitor:Add(self.Resources.ReadyChanged:Connect(function()
		if self.Resources.Ready.Value then
			self:_RecordLastValidTransforms()
			self:_UpdatePoint()
		end
	end), "Disconnect")

	if self.Resources.Ready.Value then
		self:_RecordLastValidTransforms()
	end

	return self
end

function TorsoIKBase:UpdateTransformOnly()
	if not self.RelWaistTransform or not self.RelNeckTransform then
		return
	end

	if not self.Resources.Ready.Value then
		return
	end

	local Waist = self.Resources:Get("Waist")
	local Neck = self.Resources:Get("Neck")

	-- Waist:
	local CurrentWaistTransform = Waist.Transform
	if self.LastWaistTransform ~= CurrentWaistTransform then
		self.LastValidWaistTransform = CurrentWaistTransform
	end

	Waist.Transform = self.LastValidWaistTransform * self.RelWaistTransform
	self.LastWaistTransform = Waist.Transform -- NOTE: Have to read this from the weld, otherwise comparison is off

	-- Neck:
	local CurrentNeckTransform = Neck.Transform
	if self.LastNeckTransform ~= CurrentNeckTransform then
		self.LastValidNeckTransform = CurrentNeckTransform
	end

	Neck.Transform = self.LastValidNeckTransform * self.RelNeckTransform
	self.LastNeckTransform = Neck.Transform -- NOTE: Have to read this from the weld, otherwise comparison is off
end

function TorsoIKBase:_RecordLastValidTransforms()
	assert(self.Resources.Ready.Value)
	local Waist = self.Resources:Get("Waist")
	local Neck = self.Resources:Get("Neck")

	self.LastValidWaistTransform = Waist.Transform
	self.LastWaistTransform = Waist.Transform

	self.LastValidNeckTransform = Neck.Transform
	self.LastNeckTransform = Neck.Transform
end

function TorsoIKBase:Update()
	self.RelWaistTransform = CFrame.fromOrientation(self.WaistZ:GetPosition(), self.WaistY:GetPosition(), 0)
	self.RelNeckTransform = CFrame.fromOrientation(self.HeadZ:GetPosition(), self.HeadY:GetPosition(), 0)

	self:UpdateTransformOnly()
end

function TorsoIKBase:GetTarget()
	return self.Target -- May return nil
end

function TorsoIKBase:Point(Position)
	self.Target = Position

	if self.Resources.Ready.Value then
		self:_UpdatePoint()
	end

	self.Pointed:Fire(self.Target)
end

function TorsoIKBase:_UpdatePoint()
	assert(self.Resources.Ready.Value)

	if self.Target then
		local RootPart = self.Resources:Get("RootPart")
		local WaistY, HeadY, WaistZ, HeadZ = TorsoIKUtility.GetTargetAngles(RootPart, self.Target)

		self.WaistY:SetTarget(WaistY)
		self.HeadY:SetTarget(HeadY)
		self.WaistZ:SetTarget(WaistZ)
		self.HeadZ:SetTarget(HeadZ)
	else
		self.WaistY:SetTarget(0)
		self.HeadY:SetTarget(0)
		self.WaistZ:SetTarget(0)
		self.HeadZ:SetTarget(0)
	end
end

--[=[
	Helper method used for other IK
	@return CFrame?
]=]
function TorsoIKBase:GetTargetUpperTorsoCFrame()
	if not self.Resources.Ready.Value then
		return nil
	end

	local Waist = self.Resources:Get("Waist")
	local LowerTorso = self.Resources:Get("LowerTorso")
	local EstimatedTransform = self.LastValidWaistTransform * CFrame.fromOrientation(self.WaistZ:GetTarget(), self.WaistY:GetTarget(), 0)
	return LowerTorso.CFrame * Waist.C0 * EstimatedTransform * Waist.C1:Inverse()
end

function TorsoIKBase:GetUpperTorsoCFrame()
	if not self.Resources.Ready.Value then
		return nil
	end

	return self.Resources:Get("LowerTorso").CFrame
end

function TorsoIKBase:__tostring()
	return "TorsoIKBase"
end

table.freeze(TorsoIKBase)
return TorsoIKBase
