--[=[
	Rotation model for gamepad controls
	@class GamepadRotateModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AccelTween = require(ReplicatedStorage.Knit.Util.Additions.Physics.AccelTween)
local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local CameraGamepadInputUtility = require(script.Parent.CameraGamepadInputUtility)

local GamepadRotateModel = setmetatable({}, BaseObject)
GamepadRotateModel.ClassName = "GamepadRotateModel"
GamepadRotateModel.__index = GamepadRotateModel

function GamepadRotateModel.new()
	local self = setmetatable(BaseObject.new(), GamepadRotateModel)

	self._rampVelocityX = AccelTween.new(25)
	self._rampVelocityY = AccelTween.new(25)

	self.IsRotating = self.Janitor:Add(Instance.new("BoolValue"), "Destroy")
	self.IsRotating.Value = false

	return self
end

function GamepadRotateModel:GetThumbstickDeltaAngle()
	if not self._lastInputObject then
		return Vector2.new()
	end

	return Vector2.new(self._rampVelocityX:GetPosition(), self._rampVelocityY:GetPosition())
end

function GamepadRotateModel:StopRotate()
	self._lastInputObject = nil
	self._rampVelocityX:SetTarget(0):SetPosition(0)
	self._rampVelocityY:SetTarget(0):SetPosition(0)
	self.IsRotating.Value = false
end

function GamepadRotateModel:HandleThumbstickInput(inputObject)
	if CameraGamepadInputUtility.OutOfDeadZone(inputObject) then
		self._lastInputObject = inputObject

		local stickOffset = self._lastInputObject.Position
		stickOffset = Vector2.new(-stickOffset.X, stickOffset.Y) -- Invert axis!

		local adjustedStickOffset = CameraGamepadInputUtility.GamepadLinearToCurve(stickOffset)
		self._rampVelocityX:SetTarget(adjustedStickOffset.X)
		self._rampVelocityY:SetTarget(adjustedStickOffset.Y)

		self.IsRotating.Value = true
	else
		self:StopRotate()
	end
end

function GamepadRotateModel:__tostring()
	return "GamepadRotateModel"
end

table.freeze(GamepadRotateModel)
return GamepadRotateModel
