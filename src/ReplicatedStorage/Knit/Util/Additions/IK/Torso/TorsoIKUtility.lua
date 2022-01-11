--[=[
	@class TorsoIKUtility
]=]

local IKUtility = require(script.Parent.Parent.IKUtility)

local OFFSET_Y = 0.5

local TorsoIKUtility = {}

local WaistYawClamper = IKUtility.GetDampenedAngleClamp(math.rad(20), math.rad(10))
local WaistPitchClamper = IKUtility.GetDampenedAngleClamp(math.rad(20), math.rad(10)) -- TODO: Allow forward bend by 40 degrees
local HeadYawClamper = IKUtility.GetDampenedAngleClamp(math.rad(45), math.rad(15))
local HeadPitchClamper = IKUtility.GetDampenedAngleClamp(math.rad(45), math.rad(15))

function TorsoIKUtility.GetTargetAngles(RootPart: BasePart, Target: Vector3)
	local BaseCFrame = RootPart.CFrame * CFrame.new(0, OFFSET_Y, 0)

	local OffsetWaistY = BaseCFrame:PointToObjectSpace(Target)
	local WaistY = WaistYawClamper(math.atan2(-OffsetWaistY.X, -OffsetWaistY.Z))

	local RelativeToWaistY = BaseCFrame * CFrame.Angles(0, WaistY, 0)

	local HeadOffsetY = RelativeToWaistY:PointToObjectSpace(Target)
	local HeadY = HeadYawClamper(math.atan2(-HeadOffsetY.X, -HeadOffsetY.Z))

	local RelativeToHeadY = RelativeToWaistY * CFrame.Angles(0, HeadY, 0)

	local OffsetWaistZ = RelativeToHeadY:PointToObjectSpace(Target)
	local WaistZ = WaistPitchClamper(math.atan2(OffsetWaistZ.Y, -OffsetWaistZ.Z))

	local RelativeToEverything = RelativeToHeadY * CFrame.Angles(0, 0, WaistZ)

	local HeadOffsetZ = RelativeToEverything:PointToObjectSpace(Target)
	local HeadZ = HeadPitchClamper(math.atan2(HeadOffsetZ.Y, -HeadOffsetZ.Z))

	return WaistY, HeadY, WaistZ, HeadZ
end

table.freeze(TorsoIKUtility)
return TorsoIKUtility
