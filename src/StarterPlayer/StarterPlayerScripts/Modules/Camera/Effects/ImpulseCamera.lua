--[=[
	Add another layer of effects over any other camera by allowing an "impulse"
	to be applied. Good for shockwaves, camera shake, and recoil.

	@class ImpulseCamera
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(script.Parent.Parent.CameraState)
local Debug = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Debug)
local Spring = require(ReplicatedStorage.Knit.Util.Additions.Physics.Spring)
local SummedCamera = require(script.Parent.SummedCamera)

local ImpulseCamera = {}
ImpulseCamera.ClassName = "ImpulseCamera"

function ImpulseCamera.new()
	return setmetatable({
		_spring = Spring.new(Vector3.new()):SetDamper(0.5):SetSpeed(20);
	}, ImpulseCamera)
end

--[=[
	Applies an impulse to the camera, shaking it!
	@param velocity Vector3
]=]
function ImpulseCamera:Impulse(velocity)
	assert(typeof(velocity) == "Vector3", "Bad velocity")

	self._spring:Impulse(velocity)
end

function ImpulseCamera:__add(other)
	return SummedCamera.new(self, other)
end

function ImpulseCamera:__newindex(index, value)
	if index == "Damper" then
		assert(type(value) == "number", "Bad value")
		self._spring:SetDamper(value)
	elseif index == "Speed" then
		assert(type(value) == "number", "Bad value")
		self._spring:SetSpeed(value)
	else
		Debug.Error("%q is not a valid member of impulse camera", index)
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within DefaultCamera
]=]
function ImpulseCamera:__index(index)
	if index == "CameraState" then
		local newState = CameraState.new()

		local position = self._spring:GetPosition()
		newState.CFrame = CFrame.fromOrientation(position.X, position.Y, position.Z)

		return newState
	elseif index == "Damper" then
		return self._spring.Damper
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Spring" then
		return self._spring
	else
		return ImpulseCamera[index]
	end
end

function ImpulseCamera:__tostring()
	return "ImpulseCamera"
end

table.freeze(ImpulseCamera)
return ImpulseCamera
