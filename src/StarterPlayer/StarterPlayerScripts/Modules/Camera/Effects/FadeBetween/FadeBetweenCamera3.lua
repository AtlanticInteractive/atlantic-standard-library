--[=[
	Add another layer of effects that can be faded in/out
	@class FadeBetweenCamera3
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraFrame = require(script.Parent.Parent.Parent.Utility.CameraFrame)
local CameraState = require(script.Parent.Parent.Parent.CameraState)
local CubicSplineUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CubicSplineUtility)
local Debug = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Debug)
local FieldOfViewUtility = require(script.Parent.Parent.Parent.Utility.FieldOfViewUtility)
local QFrame = require(ReplicatedStorage.Knit.Util.Additions.Vendor.QFrame)
local Spring = require(ReplicatedStorage.Knit.Util.Additions.Physics.Spring)
local SpringUtility = require(ReplicatedStorage.Knit.Util.Additions.Physics.SpringUtility)
local SummedCamera = require(script.Parent.Parent.SummedCamera)

local FadeBetweenCamera3 = {}
FadeBetweenCamera3.ClassName = "FadeBetweenCamera3"

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera3
]=]
function FadeBetweenCamera3.new(cameraA, cameraB)
	local self = setmetatable({
		_spring = Spring.new(0);
		CameraA = cameraA or error("No cameraA");
		CameraB = cameraB or error("No cameraB");
	}, FadeBetweenCamera3)

	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera3:__add(other)
	return SummedCamera.new(self, other)
end

function FadeBetweenCamera3:__newindex(index, value)
	if index == "Damper" then
		self._spring:SetDamper(value)
	elseif index == "Value" then
		self._spring:SetPosition(value)
	elseif index == "Speed" then
		self._spring:SetSpeed(value)
	elseif index == "Target" then
		self._spring:SetTarget(value)
	elseif index == "Velocity" then
		self._spring:SetVelocity(value)
	elseif index == "CameraA" or index == "CameraB" then
		rawset(self, index, value)
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera3", index)
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera3
]=]
function FadeBetweenCamera3:__index(index)
	if index == "CameraState" then
		local _, t = SpringUtility.Animating(self._spring)
		if t == 0 then
			return self.CameraStateA
		elseif t == 1 then
			return self.CameraStateB
		else
			local stateA = self.CameraStateA
			local stateB = self.CameraStateB

			local frameA = stateA.CameraFrame
			local frameB = stateB.CameraFrame

			local dist = (frameA.Position - frameB.Position).Magnitude

			local node0 = CubicSplineUtility.NewSplineNode(0, frameA.Position, stateA.CameraFrameDerivative.Position + frameA.CFrame.LookVector * dist * 0.3)
			local node1 = CubicSplineUtility.NewSplineNode(1, frameB.Position, stateB.CameraFrameDerivative.Position + frameB.CFrame.LookVector * dist * 0.3)

			-- We do the position this way because 0^-1 is undefined
			--stateA.Position + (stateB.Position - stateA.Position)*t
			local newNode = CubicSplineUtility.TweenSplineNodes(node0, node1, t)
			local delta = frameB * (frameA ^ -1)

			local deltaQFrame = delta.QFrame
			if deltaQFrame.W < 0 then
				delta.QFrame = QFrame.new(deltaQFrame.x, deltaQFrame.y, deltaQFrame.z, -deltaQFrame.W, -deltaQFrame.X, -deltaQFrame.Y, -deltaQFrame.Z)
			end

			local newState = delta ^ t * frameA
			newState.FieldOfView = FieldOfViewUtility.LerpInHeightSpace(frameA.FieldOfView, frameB.FieldOfView, t)
			newState.Position = newNode.p

			-- require("Draw").point(newState.Position)

			return CameraState.new(newState, CameraFrame.new(QFrame.FromVector3(newNode.v, QFrame.new())))
		end
	elseif index == "CameraStateA" then
		return self.CameraA.CameraState or self.CameraA
	elseif index == "CameraStateB" then
		return self.CameraB.CameraState or self.CameraB
	elseif index == "Damper" then
		return self._spring.Damper
	elseif index == "Value" then
		local _, t = SpringUtility.Animating(self._spring)
		return t
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Target" then
		return self._spring.Target
	elseif index == "Velocity" then
		local animating = SpringUtility.Animating(self._spring)
		if animating then
			return self._spring:GetVelocity()
		else
			return Vector3.new()
		end
	elseif index == "HasReachedTarget" then
		local animating = SpringUtility.Animating(self._spring)
		return not animating
	elseif index == "Spring" then
		return self._spring
	elseif FadeBetweenCamera3[index] then
		return FadeBetweenCamera3[index]
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera3", index)
	end
end

function FadeBetweenCamera3:__tostring()
	return "FadeBetweenCamera3"
end

table.freeze(FadeBetweenCamera3)
return FadeBetweenCamera3
