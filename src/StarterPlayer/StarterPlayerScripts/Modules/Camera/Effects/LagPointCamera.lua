--[=[
	Point a current element but lag behind for a smoother experience
	@class LagPointCamera
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraState = require(script.Parent.Parent.CameraState)
local Spring = require(ReplicatedStorage.Knit.Util.Additions.Physics.Spring)
local SummedCamera = require(script.Parent.SummedCamera)

local LagPointCamera = {}
LagPointCamera.ClassName = "LagPointCamera"
LagPointCamera._FocusCamera = nil
LagPointCamera._OriginCamera = nil

--
-- @constructor
-- @param originCamera A camera to use
-- @param focusCamera The Camera to look at.
function LagPointCamera.new(originCamera, focusCamera)
	local self = setmetatable({}, LagPointCamera)

	self.FocusSpring = Spring.new(Vector3.new())
	self.OriginCamera = originCamera or error("Must have originCamera")
	self.FocusCamera = focusCamera or error("Must have focusCamera")
	self.Speed = 10

	return self
end

function LagPointCamera:__add(other)
	return SummedCamera.new(self, other)
end

function LagPointCamera:__newindex(index, value)
	if index == "FocusCamera" then
		rawset(self, "_" .. index, value)
		local target = self.FocusCamera.CameraState.Position
		self.FocusSpring:SetTarget(target):SetPosition(target):SetVelocity(Vector3.new())
	elseif index == "OriginCamera" then
		rawset(self, "_" .. index, value)
	elseif index == "LastFocusUpdate" or index == "FocusSpring" then
		rawset(self, index, value)
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		local setter = self.FocusSpring["Set" .. index]
		setter(self.FocusSpring, value)
	else
		error(index .. " is not a valid member of LagPointCamera")
	end
end

function LagPointCamera:__index(index)
	if index == "CameraState" then
		local origin, focusPosition = self.Origin, self.FocusPosition

		local state = CameraState.new()
		state.FieldOfView = origin.FieldOfView + self.FocusCamera.CameraState.FieldOfView
		state.CFrame = CFrame.new(origin.Position, focusPosition)

		return state
	elseif index == "FocusPosition" then
		local delta
		if self.LastFocusUpdate then
			delta = os.clock() - self.LastFocusUpdate
		end

		self.LastFocusUpdate = os.clock()
		self.FocusSpring:SetTarget(self.FocusCamera.CameraState.Position)

		if delta then
			self.FocusSpring:TimeSkip(delta)
		end

		return self.FocusSpring:GetPosition()
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		local getter = self.FocusSpring["Get" .. index]
		return getter(self.FocusSpring)
	elseif index == "Origin" then
		return self.OriginCamera.CameraState
	elseif index == "FocusCamera" or index == "OriginCamera" then
		return rawget(self, "_" .. index) or error("Internal error: index does not exist")
	else
		return LagPointCamera[index]
	end
end

function LagPointCamera:__tostring()
	return "LagPointCamera"
end

table.freeze(LagPointCamera)
return LagPointCamera
