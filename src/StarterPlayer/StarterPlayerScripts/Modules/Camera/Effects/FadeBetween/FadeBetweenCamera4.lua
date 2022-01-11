--[=[
	@class FadeBetweenCamera4
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(script.Parent.Parent.Parent.CameraState)
local CubicSplineUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CubicSplineUtility)
local Debug = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Debug)
local Spring = require(ReplicatedStorage.Knit.Util.Additions.Physics.Spring)
local SpringUtility = require(ReplicatedStorage.Knit.Util.Additions.Physics.SpringUtility)

local FadeBetweenCamera4 = {}
FadeBetweenCamera4.ClassName = "FadeBetweenCamera4"

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera4
]=]
function FadeBetweenCamera4.new(cameraA, cameraB)
	return setmetatable({
		CameraA = cameraA or error("No cameraA");
		CameraB = cameraB or error("No cameraB");
		_spring = Spring.new():SetSpeed(15);
		_position0 = 0;
		_state0 = cameraA.CameraState;
	}, FadeBetweenCamera4)
end

function FadeBetweenCamera4:__newindex(index, value)
	if index == "Value" then
		assert(type(value) == "number", "Bad value")

		local _, position = SpringUtility.Animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		self._spring:SetPosition(value)
	elseif index == "Target" then
		assert(type(value) == "number", "Bad value")

		local _, position = SpringUtility.Animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		self._spring:SetTarget(value)
	elseif index == "Speed" then
		assert(type(value) == "number", "Bad value")

		local _, position = SpringUtility.Animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		self._spring:SetSpeed(value)
	elseif index == "CameraA" or index == "CameraB" then
		assert(type(value) ~= "nil", "Bad value")

		local _, position = SpringUtility.Animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		rawset(self, index, value)
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera4", index)
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera4
]=]
function FadeBetweenCamera4:__index(index)
	if index == "CameraState" then
		local _, value = SpringUtility.Animating(self._spring)
		return self:_computeCameraState(value)
	elseif index == "Value" then
		local _, value = SpringUtility.Animating(self._spring)
		return value
	elseif index == "Target" then
		return self._spring.Target
	elseif index == "HasReachedTarget" then
		return SpringUtility.Animating(self._spring)
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Velocity" then
		return self._spring:GetVelocity()
	elseif FadeBetweenCamera4[index] then
		return FadeBetweenCamera4[index]
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera4", index)
	end
end

function FadeBetweenCamera4:_computeTargetState(target)
	if target <= 0 then
		return self.CameraA.CameraState
	elseif target >= 1 then
		return self.CameraB.CameraState
	else
		-- Perform initial interpolation to get target (uncommon requirement)
		local a = self.CameraA.CameraState
		local b = self.CameraB.CameraState

		local node0 = CubicSplineUtility.NewSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		local node1 = CubicSplineUtility.NewSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)
		local newNode = CubicSplineUtility.TweenSplineNodes(node0, node1, self._spring.t)

		return CameraState.new(newNode.p, newNode.v)
	end
end

function FadeBetweenCamera4:_computeCameraState(position)
	if position <= 0 then
		return self:_computeTargetState(0), 0
	elseif position >= 1 then
		return self:_computeTargetState(1), 1
	end

	local node0, node1
	if position < self._position0 then -- assume target is also moving in this direction
		local a = self:_computeTargetState(0)

		node0 = CubicSplineUtility.NewSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		node1 = CubicSplineUtility.NewSplineNode(self._position0, self._state0.CameraFrame, self._state0.CameraFrameDerivative)
	else
		local b = self:_computeTargetState(1)

		node0 = CubicSplineUtility.NewSplineNode(self._position0, self._state0.CameraFrame, self._state0.CameraFrameDerivative)
		node1 = CubicSplineUtility.NewSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)
	end

	local newNode = CubicSplineUtility.TweenSplineNodes(node0, node1, position)

	local newState = CameraState.new(newNode.p, newNode.v)
	return newState, position
end

function FadeBetweenCamera4:__tostring()
	return "FadeBetweenCamera4"
end

table.freeze(FadeBetweenCamera4)
return FadeBetweenCamera4
