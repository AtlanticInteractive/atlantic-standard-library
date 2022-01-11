--[=[
	@class FadeBetweenCamera2
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(script.Parent.Parent.Parent.CameraState)
local CubicSplineUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CubicSplineUtility)
local Debug = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Debug)

local FadeBetweenCamera2 = {}
FadeBetweenCamera2.ClassName = "FadeBetweenCamera2"

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera2
]=]
function FadeBetweenCamera2.new(cameraA, cameraB)
	return setmetatable({
		CameraA = cameraA or error("No cameraA");
		CameraB = cameraB or error("No cameraB");
		_state0 = cameraA.CameraState;
		_time0 = os.clock();
		_target = 0;
		_position0 = 0;
		_speed = 15;
	}, FadeBetweenCamera2)
end

function FadeBetweenCamera2:__newindex(index, value)
	if index == "Value" then
		assert(type(value) == "number", "Bad value")

		if self._position0 ~= value then
			local now = os.clock()
			self._state0, self._position0 = self:_computeCameraState(value)
			self._time0 = now
		end
	elseif index == "Target" then
		assert(type(value) == "number", "Bad value")
		if self._target ~= value then
			local now = os.clock()
			self._state0, self._position0 = self:_computeCameraState(self:_computeDoneProportion(now))
			self._time0 = now
			self._target = value
		end
	elseif index == "Speed" then
		assert(type(value) == "number", "Bad value")

		if self._speed ~= value then
			local now = os.clock()
			self._state0, self._position0 = self:_computeCameraState(self:_computeDoneProportion(now))
			self._time0 = now
			self._speed = value
		end
	elseif index == "CameraA" or index == "CameraB" then
		local now = os.clock()
		self._state0, self._position0 = self:_computeCameraState(self:_computeDoneProportion(now))
		self._time0 = now
		rawset(self, index, value)
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera2", index)
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera2
]=]
function FadeBetweenCamera2:__index(index)
	if index == "CameraState" then
		local state = self:_computeCameraState(self:_computeDoneProportion(os.clock()))
		return state
	elseif index == "Value" then
		return self:_computeDoneProportion(os.clock())
	elseif index == "Target" then
		return self._target
	elseif index == "HasReachedTarget" then
		return self:_computeDoneProportion(os.clock()) >= 1
	elseif index == "Speed" then
		return self._speed
	elseif index == "Velocity" then
		return self._speed
	elseif FadeBetweenCamera2[index] then
		return FadeBetweenCamera2[index]
	else
		Debug.Error("%q is not a valid member of FadeBetweenCamera2", index)
	end
end

function FadeBetweenCamera2:_computeTargetState()
	if self._target == 0 then
		return self.CameraA.CameraState
	elseif self._target == 1 then
		return self.CameraB.CameraState
	else
		-- Perform initial interpolation to get target (uncommon requirement)
		local a = self.CameraA.CameraState
		local b = self.CameraB.CameraState

		local node0 = CubicSplineUtility.NewSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		local node1 = CubicSplineUtility.NewSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)
		local newNode = CubicSplineUtility.TweenSplineNodes(node0, node1, self._target)

		return CameraState.new(newNode.p, newNode.v)
	end
end

function FadeBetweenCamera2:_computeCameraState(t)
	if t <= 0 then
		return self._state0, 0
	end

	if t >= 1 then
		return self:_computeTargetState(), 1
	else
		local a = self._state0
		local b = self:_computeTargetState()

		local node0 = CubicSplineUtility.NewSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		local node1 = CubicSplineUtility.NewSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)

		local newNode = CubicSplineUtility.TweenSplineNodes(node0, node1, t)

		return CameraState.new(newNode.p, newNode.v), t
	end
end

function FadeBetweenCamera2:_computeDoneProportion(now)
	local dist_to_travel = math.abs(self._position0 - self._target)
	if dist_to_travel == 0 then
		return 1
	end

	local SPEED_CONSTANT = 0.5 / 15 -- 0.5 seconds is 15 speed in the other system
	return math.clamp(self._speed * (now - self._time0) * SPEED_CONSTANT / dist_to_travel, 0, 1)
end

function FadeBetweenCamera2:__tostring()
	return "FadeBetweenCamera2"
end

table.freeze(FadeBetweenCamera2)
return FadeBetweenCamera2
