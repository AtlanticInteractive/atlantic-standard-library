--!strict

--[[
	Manages batch updating of spring objects.
]]

local RunService = game:GetService("RunService")

local Package = script.Parent.Parent
local PubTypes = require(Package.PubTypes)
local Types = require(Package.Types)
local packType = require(Package.Animation.packType)
local springCoefficients = require(Package.Animation.springCoefficients)
local updateAll = require(Package.Dependencies.updateAll)
local logError = require(Package.Logging.logError)

type Set<T> = {[T]: any}
type Spring = Types.Spring<any>

local SpringScheduler = {}

-- when a spring has displacement and velocity below +/- epsilon, the spring
-- won't send updates
local MOVEMENT_EPSILON = 0.0001

-- organises springs by speed and damping, for batch processing
local springBuckets: {{Set<Spring>}} = {}

--[[
	Adds a Spring to be updated every render step.
]]
function SpringScheduler.add(spring: Spring)
	local damping: number
	local speed: number

	if spring._dampingIsState then
		local state = spring._damping :: PubTypes.StateObject<number>
		damping = state:Get(false)
	else
		damping = spring._damping :: number
	end

	if spring._speedIsState then
		local state = spring._speed :: PubTypes.StateObject<number>
		speed = (state :: PubTypes.StateObject<number>):Get(false)
	else
		speed = spring._speed :: number
	end

	if type(damping) ~= "number" then
		logError("mistypedSpringDamping", nil, typeof(damping))
	elseif damping < 0 then
		logError("invalidSpringDamping", nil, damping)
	end

	if type(speed) ~= "number" then
		logError("mistypedSpringSpeed", nil, typeof(speed))
	elseif speed < 0 then
		logError("invalidSpringSpeed", nil, speed)
	end

	spring._lastDamping = damping
	spring._lastSpeed = speed

	local dampingBucket = springBuckets[damping]

	if dampingBucket == nil then
		dampingBucket = {}
		springBuckets[damping] = dampingBucket
	end

	local speedBucket = dampingBucket[speed]

	if speedBucket == nil then
		speedBucket = {}
		dampingBucket[speed] = speedBucket
	end

	speedBucket[spring] = true
end

--[[
	Removes a Spring from the scheduler.
]]
function SpringScheduler.remove(spring: Spring)
	local damping = spring._lastDamping
	local speed = spring._lastSpeed

	local dampingBucket = springBuckets[damping]
	if dampingBucket == nil then
		return
	end

	local speedBucket = dampingBucket[speed]
	if speedBucket == nil then
		return
	end

	speedBucket[spring] = nil
end

--[[
	Updates all Spring objects.
]]
local function updateAllSprings(timeStep: number)
	for damping, dampingBucket in next, springBuckets do
		for speed, speedBucket in next, dampingBucket do
			local posPosCoef, posVelCoef, velPosCoef, velVelCoef = springCoefficients(timeStep, damping, speed)

			for spring in next, speedBucket do
				local goals = spring._springGoals
				local positions = spring._springPositions
				local velocities = spring._springVelocities

				local isMoving = false

				for index, goal in ipairs(goals) do
					local oldPosition = positions[index]
					local oldVelocity = velocities[index]

					local oldDisplacement = oldPosition - goal

					local newDisplacement = oldDisplacement * posPosCoef + oldVelocity * posVelCoef
					local newVelocity = oldDisplacement * velPosCoef + oldVelocity * velVelCoef

					if math.abs(newDisplacement) > MOVEMENT_EPSILON or math.abs(newVelocity) > MOVEMENT_EPSILON then
						isMoving = true
					end

					positions[index] = newDisplacement + goal
					velocities[index] = newVelocity
				end

				-- if the spring moved a significant distance, update its
				-- current value, otherwise stop animating
				if isMoving then
					spring._currentValue = packType(positions, spring._currentType)
					updateAll(spring)
				else
					SpringScheduler.remove(spring)
				end
			end
		end
	end
end

RunService:BindToRenderStep("__FusionSpringScheduler", Enum.RenderPriority.First.Value, updateAllSprings)
table.freeze(SpringScheduler)
return SpringScheduler
