--[=[
	Handles repliation and aiming of the local player's character for
	IK.

	@client
	@class IKRigAimerLocalPlayer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local GetController = require(ReplicatedStorage.Knit.Util.GetController)
local IKAimPositionPriorities = require(ReplicatedStorage.Knit.Util.Additions.IK.Arm.IKAimPositionPriorities)

local MAX_AGE_FOR_AIM_DATA = 0.2
local REPLICATION_RATE = 1.3

local IKRigAimerLocalPlayer = setmetatable({}, BaseObject)
IKRigAimerLocalPlayer.ClassName = "IKRigAimerLocalPlayer"
IKRigAimerLocalPlayer.__index = IKRigAimerLocalPlayer

function IKRigAimerLocalPlayer.new(IkRig, RemoteEvent)
	local self = setmetatable(BaseObject.new(), IKRigAimerLocalPlayer)

	self.CameraStackController = GetController("CameraStackController")
	self.RemoteEvent = RemoteEvent or error("No remoteEvent")
	self.IkRig = IkRig or error("No ikRig")

	self.LastUpdate = 0
	self.LastReplication = 0
	self.AimData = nil
	self.LookAround = true

	return self
end

function IKRigAimerLocalPlayer:SetLookAround(LookAround)
	self.LookAround = LookAround
end

-- @param position May be nil
function IKRigAimerLocalPlayer:SetAimPosition(Position, OptionalPriority: number?)
	local Priority = OptionalPriority or IKAimPositionPriorities.DEFAULT

	if self.AimData and os.clock() - self.AimData.Timestamp < MAX_AGE_FOR_AIM_DATA then
		if self.AimData.Priority > Priority then
			return -- Don't overwrite
		end
	end

	self.AimData = {
		Position = Position; -- May be nil
		Priority = OptionalPriority;
		Timestamp = os.clock();
	}
end

function IKRigAimerLocalPlayer:GetAimDirection()
	if self.AimData and os.clock() - self.AimData.Timestamp < MAX_AGE_FOR_AIM_DATA then
		-- If we have aim data within the last 0.2 seconds start pointing at that
		return self.AimData.Position -- May be nil
	end

	if not self.LookAround then
		return nil
	end

	local Humanoid = self.IkRig:GetHumanoid()

	local CameraCFrame = self.CameraStackController:GetRawDefaultCamera().CameraState.CFrame
	local CharacterCFrame = Humanoid.RootPart and Humanoid.RootPart.CFrame
	local Multiplier = 1000

	-- Make the character look at the camera instead of trying to turn 180
	if CharacterCFrame then
		local Relative = CameraCFrame:VectorToObjectSpace(CharacterCFrame.LookVector)
		if math.acos(Relative.Z) < math.rad(60) then
			Multiplier = -Multiplier
		end
	end

	return CameraCFrame.Position + CameraCFrame.LookVector * Multiplier
end

function IKRigAimerLocalPlayer:UpdateStepped()
	if os.clock() - self.LastUpdate <= 0.05 then
		return
	end

	local AimDirection = self:GetAimDirection()

	self.LastUpdate = os.clock()
	local Torso = self.IkRig:GetTorso()
	if Torso then
		Torso:Point(AimDirection)
	end

	-- Filter replicate
	if os.clock() - self.LastReplication > REPLICATION_RATE then
		self.LastReplication = os.clock()
		self.RemoteEvent:FireServer(AimDirection)
	end
end

function IKRigAimerLocalPlayer:__tostring()
	return "IKRigAimerLocalPlayer"
end

table.freeze(IKRigAimerLocalPlayer)
return IKRigAimerLocalPlayer
