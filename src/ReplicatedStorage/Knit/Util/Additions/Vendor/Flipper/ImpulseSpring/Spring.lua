--[[
class Spring

Description:
	A physical model of a spring, useful in many applications. Properties only evaluate
	upon index making this model good for lazy applications

API:
	Spring = Spring.new(number position)
		Creates a new spring in 1D
	Spring = Spring.new(Vector3 position)
		Creates a new spring in 3D

	Spring:GetPosition()
		Returns the current position
	Spring:GetVelocity()
		Returns the current velocity
	Spring:GetTarget()
		Returns the target
	Spring:GetDamper()
		Returns the damper
	Spring:GetSpeed()
		Returns the speed

	Spring:SetTarget(number/Vector3)
		Sets the target
	Spring:SetPosition(number/Vector3)
		Sets the position
	Spring:SetVelocity(number/Vector3)
		Sets the velocity
	Spring:SetDamper(number [0, 1])
		Sets the spring damper, defaults to 1
	Spring:SetSpeed(number [0, infinity))
		Sets the spring speed, defaults to 1

	Spring:TimeSkip(number DeltaTime)
		Instantly skips the spring forwards by that amount of now
	Spring:Impulse(number/Vector3 velocity)
		Impulses the spring, increasing velocity by the amount given

Visualization (by Defaultio):
	https://www.desmos.com/calculator/hn2i9shxbz
]]

-- based spring
-- this is better because it doesn't use `__index` as a function or `__newindex`, which provides a massive speed increase over the original.

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Resources = require(ReplicatedStorage:WaitForChild("Resources"))
-- local Multithreader = Resources.LoadLibrary("Multithreader")
-- local Spy = Resources.LoadLibrary("Spy")
-- local Utility = script.Utility

local Spring = {}
Spring.ClassName = "Spring"
Spring.__index = Spring

--- Creates a new spring
-- @param initial A number or Vector3 (anything with * number and addition/subtraction defined)
-- @param[opt=tick] clock function to use to update spring
function Spring.new(initial)
	local target = initial or 0
	return setmetatable({
		_position0 = target;
		_velocity0 = 0 * target;
		_target = target;
		_damper = 1;
		_speed = 1;
	}, Spring)
end

local function PositionVelocity(self, DeltaTime: number)
	local p0 = self._position0
	local v0 = self._velocity0
	local p1 = self._target
	local d = self._damper
	local s = self._speed

	local t = s * DeltaTime
	local d2 = d * d

	local h, si, co
	if d2 < 1 then
		h = math.sqrt(1 - d2)
		local ep = math.exp(-d * t) / h
		co, si = ep * math.cos(h * t), ep * math.sin(h * t)
	elseif d2 == 1 then
		h = 1
		local ep = math.exp(-d * t) / h
		co, si = ep, ep * t
	else
		h = math.sqrt(d2 - 1)
		local u = math.exp((-d + h) * t) / (2 * h)
		local v = math.exp((-d - h) * t) / (2 * h)
		co, si = u + v, u - v
	end

	local a0 = h * co + d * si
	local a1 = 1 - (h * co + d * si)
	local a2 = si / s

	local b0 = -s * si
	local b1 = s * si
	local b2 = h * co - d * si

	return a0 * p0 + a1 * p1 + a2 * v0, b0 * p0 + b1 * p1 + b2 * v0
end

-- local Multithreader_Runner_Run = Multithreader.Runner.Run

-- local function BasePositionVelocity(self, DeltaTime: number)
-- 	return Multithreader_Runner_Run(Utility, "PositionVelocity", self, DeltaTime)
-- end

-- local PositionVelocity = Spy.Benchmark(BasePositionVelocity, "PositionVelocity")

--- Impulse the spring with a change in velocity
-- @param velocity The velocity to impulse with
function Spring:Impulse(Velocity, DeltaTime: number)
	return self:SetVelocity(self:GetVelocity(DeltaTime) + Velocity, DeltaTime)
end

function Spring:GetPosition(DeltaTime: number)
	return (PositionVelocity(self, DeltaTime))
end

Spring.GetValue = Spring.GetPosition

function Spring:GetVelocity(DeltaTime: number)
	local _, Velocity = PositionVelocity(self, DeltaTime)
	return Velocity
end

function Spring:GetTarget()
	return self._target
end

function Spring:GetDamper()
	return self._damper
end

function Spring:GetSpeed()
	return self._speed
end

function Spring:SetPosition(Value, DeltaTime: number)
	local _, velocity = PositionVelocity(self, DeltaTime)
	self._position0 = Value
	self._velocity0 = velocity
	return self
end

Spring.SetValue = Spring.SetPosition

function Spring:SetVelocity(Value, DeltaTime: number)
	self._position0 = PositionVelocity(self, DeltaTime)
	self._velocity0 = Value
	return self
end

function Spring:SetTarget(Value, DeltaTime: number)
	self._position0, self._velocity0 = PositionVelocity(self, DeltaTime)
	self._target = Value
	return self
end

function Spring:SetDamper(Value, DeltaTime: number)
	self._position0, self._velocity0 = PositionVelocity(self, DeltaTime)
	self._damper = math.clamp(Value, 0, 1)
	return self
end

function Spring:SetSpeed(Value, DeltaTime: number)
	self._position0, self._velocity0 = PositionVelocity(self, DeltaTime)
	self._speed = Value < 0 and 0 or Value
	return self
end

function Spring:__tostring()
	return "Spring"
end

return Spring
