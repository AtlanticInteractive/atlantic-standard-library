--[=[
	Add another layer of effects that can be faded in/out
	@class FadeBetweenCamera
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraState = require(script.Parent.Parent.Parent.CameraState)
local CubicSplineUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CubicSplineUtility)
local Debug = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Debug)
local Spring = require(ReplicatedStorage.Knit.Util.Additions.Physics.Spring)
local SpringUtility = require(ReplicatedStorage.Knit.Util.Additions.Physics.SpringUtility)
local SummedCamera = require(script.Parent.Parent.SummedCamera)

local FadeBetweenCamera = {}
FadeBetweenCamera.ClassName = "FadeBetweenCamera"

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera
]=]
function FadeBetweenCamera.new(cameraA, cameraB)
	local self = setmetatable({
		_spring = Spring.new(0);
		CameraA = cameraA or error("No cameraA");
		CameraB = cameraB or error("No cameraB");
	}, FadeBetweenCamera)

	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera:__add(other)
	return SummedCamera.new(self, other)
end

function FadeBetweenCamera:__newindex(index, value)
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
		Debug.Error("%q is not a valid member of FadeBetweenCamera", index)
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera
]=]
function FadeBetweenCamera:__index(index)
	if index == "CameraState" then
		local _, t = SpringUtility.Animating(self._spring)
		if t <= 0 then
			return self.CameraStateA
		elseif t >= 1 then
			return self.CameraStateB
		else
			local a = self.CameraStateA
			local b = self.CameraStateB

			local node0 = CubicSplineUtility.NewSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
			local node1 = CubicSplineUtility.NewSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)

			local newNode = CubicSplineUtility.TweenSplineNodes(node0, node1, t)
			return CameraState.new(newNode.p, newNode.v)
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
	elseif FadeBetweenCamera[index] then
		return FadeBetweenCamera[index]
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera", index)
	end
end

function FadeBetweenCamera:__tostring()
	return "FadeBetweenCamera"
end

table.freeze(FadeBetweenCamera)
return FadeBetweenCamera
