--[=[
	Makes transitions between states easier. Uses the `CameraStackService` to tween in and
	out a new camera state Call `:Show()` and `:Hide()` to do so, and make sure to
	call `:Destroy()` after usage

	@class CameraStateTweener
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetController = require(ReplicatedStorage.Knit.Util.GetController)
local FadeBetweenCamera3 = require(script.Parent.Parent.Effects.FadeBetween.FadeBetweenCamera3)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)

local CameraStateTweener = {}
CameraStateTweener.ClassName = "CameraStateTweener"
CameraStateTweener.__index = CameraStateTweener

--[=[
	Constructs a new camera state tweener

	@param cameraEffect CameraLike -- A camera effect
	@param speed number? -- Speed that the camera tweener tweens at. Defaults to 20
	@return CameraStateTweener
]=]
function CameraStateTweener.new(cameraEffect, speed)
	local self = setmetatable({}, CameraStateTweener)

	assert(cameraEffect, "No cameraEffect")

	self._janitor = Janitor.new()

	self._cameraStackController = GetController("CameraStackController")
	local cameraBelow, assign = self._cameraStackController:GetNewStateBelow()

	self._cameraEffect = cameraEffect
	self._cameraBelow = cameraBelow
	self._fadeBetween = FadeBetweenCamera3.new(cameraBelow, cameraEffect)
	assign(self._fadeBetween)

	self._cameraStackController:Add(self._fadeBetween)

	self._fadeBetween.Speed = speed or 20
	self._fadeBetween.Target = 0
	self._fadeBetween.Value = 0

	self._janitor:Add(function()
		self._cameraStackController:Remove(self._fadeBetween)
	end, true)

	return self
end

--[=[
	Returns percent visible, from 0 to 1.
	@return number
]=]
function CameraStateTweener:GetPercentVisible()
	return self._fadeBetween.Value
end

--[=[
	Shows the camera to fade in.
	@param doNotAnimate? boolean -- Optional, defaults to animating
]=]
function CameraStateTweener:Show(doNotAnimate)
	self:SetTarget(1, doNotAnimate)
end

--[=[
	Hides the camera to fade in.
	@param doNotAnimate? boolean -- Optional, defaults to animating
]=]
function CameraStateTweener:Hide(doNotAnimate)
	self:SetTarget(0, doNotAnimate)
end

--[=[
	Returns true if we're done hiding
	@return boolean
]=]
function CameraStateTweener:IsFinishedHiding()
	return self._fadeBetween.HasReachedTarget and self._fadeBetween.Target == 0
end

--[=[
	Hides the tweener, and invokes the callback once the tweener
	is finished hiding.
	@param doNotAnimate boolean? -- Optional, defaults to animating
	@param callback function
]=]
function CameraStateTweener:Finish(doNotAnimate, callback)
	self:Hide(doNotAnimate)

	if self._fadeBetween.HasReachedTarget then
		callback()
	else
		task.spawn(function()
			while not self._fadeBetween.HasReachedTarget do
				task.wait(0.05)
			end

			callback()
		end)
	end
end

--[=[
	Gets the current effect we're tweening
	@return CameraEffect
]=]
function CameraStateTweener:GetCameraEffect()
	return self._cameraEffect
end

--[=[
	Gets the camera below this camera on the camera stack
	@return CameraEffect
]=]
function CameraStateTweener:GetCameraBelow()
	return self._cameraBelow
end

--[=[
	Sets the percent visible target
	@param target number
	@param doNotAnimate boolean? -- Optional, defaults to animating
	@return CameraStateTweener -- self
]=]
function CameraStateTweener:SetTarget(target, doNotAnimate)
	self._fadeBetween.Target = target or error("No target")
	if doNotAnimate then
		self._fadeBetween.Value = self._fadeBetween.Target
		self._fadeBetween.Velocity = 0
	end

	return self
end

--[=[
	Sets the speed of transition
	@param speed number
	@return CameraStateTweener -- self
]=]
function CameraStateTweener:SetSpeed(speed)
	self._fadeBetween.Speed = speed

	return self
end

--[=[
	Sets whether the tweener is visible
	@param isVisible boolean
	@param doNotAnimate boolean? -- Optional, defaults to animating
]=]
function CameraStateTweener:SetVisible(isVisible, doNotAnimate)
	if isVisible then
		self:Show(doNotAnimate)
	else
		self:Hide(doNotAnimate)
	end
end

--[=[
	Retrieves the fading camera being used to interpolate.
	@return CameraEffect
]=]
function CameraStateTweener:GetFader()
	return self._fadeBetween
end

--[=[
	Cleans up the fader, preventing any animation at all
]=]
function CameraStateTweener:Destroy()
	self._janitor:Destroy()
	setmetatable(self, nil)
end

function CameraStateTweener:__tostring()
	return "CameraStateTweener"
end

table.freeze(CameraStateTweener)
return CameraStateTweener
