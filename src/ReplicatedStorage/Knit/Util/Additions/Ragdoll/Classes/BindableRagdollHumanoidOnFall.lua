--[=[
	Ragdolls the humanoid on fall. This is the base class.
	@class BindableRagdollHumanoidOnFall
]=]

local BaseObject = require(script.Parent.Parent.Parent.Classes.BaseObject)

local BindableRagdollHumanoidOnFall = setmetatable({}, BaseObject)
BindableRagdollHumanoidOnFall.ClassName = "BindableRagdollHumanoidOnFall"
BindableRagdollHumanoidOnFall.__index = BindableRagdollHumanoidOnFall

local FRAMES_TO_EXAMINE = 8
local FRAME_TIME = 0.1
local RAGDOLL_DEBOUNCE_TIME = 1
local REQUIRED_MAX_FALL_VELOCITY = -30

-- local function InitializeLastVelocityRecords(self)
-- 	self.LastVelocityRecords = table.create(FRAMES_TO_EXAMINE + 1, Vector3.new())
-- 	for _ = 1, FRAMES_TO_EXAMINE + 1 do -- Add an extra frame because we remove before inserting
-- 		table.insert(self.LastVelocityRecords, Vector3.new())
-- 	end
-- end

local function GetLargestSpeedInRecords(self)
	local LargestSpeed = -math.huge

	for _, VelocityRecord in ipairs(self.LastVelocityRecords) do
		local Speed = VelocityRecord.Magnitude
		if Speed > LargestSpeed then
			LargestSpeed = Speed
		end
	end

	return LargestSpeed
end

local function RagdollFromFall(self)
	self.ShouldRagdoll.Value = true

	task.spawn(function()
		while self.Destroy and GetLargestSpeedInRecords(self) >= 3 and self.ShouldRagdoll.Value do
			task.wait(0.05)
		end

		if self.Destroy and self.ShouldRagdoll.Value then
			task.wait(0.75)
		end

		if self.Destroy and self.Object.Health > 0 then
			self.ShouldRagdoll.Value = false
		end
	end)
end

local function UpdateVelocity(self)
	table.remove(self.LastVelocityRecords, 1)

	local RootPart = self.Object.RootPart
	if not RootPart then
		return table.insert(self.LastVelocityRecords, Vector3.new())
	end

	local CurrentVelocity = RootPart.AssemblyLinearVelocity

	local FellForAllFrames = true
	local MostNegativeVelocityY = math.huge
	for _, VelocityRecord in ipairs(self.LastVelocityRecords) do
		if VelocityRecord.Y >= -2 then
			FellForAllFrames = false
			break
		end

		if VelocityRecord.Y < MostNegativeVelocityY then
			MostNegativeVelocityY = VelocityRecord.Y
		end
	end

	table.insert(self.LastVelocityRecords, CurrentVelocity)
	if not FellForAllFrames or MostNegativeVelocityY >= REQUIRED_MAX_FALL_VELOCITY or self.Object.Health <= 0 or self.Object.Sit then
		return
	end

	local CurrentState = self.Object:GetState()
	if CurrentState == Enum.HumanoidStateType.Physics or CurrentState == Enum.HumanoidStateType.Swimming or os.clock() - self.LastRagdollTime <= RAGDOLL_DEBOUNCE_TIME then
		return
	end

	RagdollFromFall(self)
end

--[=[
	Constructs a new BindableRagdollHumanoidOnFall.
	@param humanoid Humanoid
	@param ragdollBinder Binder<Ragdoll | RagdollClient>
	@return BindableRagdollHumanoidOnFall
]=]
function BindableRagdollHumanoidOnFall.new(Humanoid: Humanoid, RagdollBinder)
	local self = setmetatable(BaseObject.new(Humanoid), BindableRagdollHumanoidOnFall)

	self.RagdollBinder = assert(RagdollBinder, "Bad ragdollBinder")

	--- @type BoolValue
	self.ShouldRagdoll = self.Janitor:Add(Instance.new("BoolValue"), "Destroy")
	self.ShouldRagdoll.Value = false

	-- Setup Ragdoll
	self.LastVelocityRecords = table.create(FRAMES_TO_EXAMINE + 1, Vector3.new())
	self.LastRagdollTime = 0

	local Alive = true
	self.Janitor:Add(function()
		Alive = false
	end, true)

	task.spawn(function()
		task.wait(math.random() * FRAME_TIME) -- Apply jitter
		while Alive do
			UpdateVelocity(self)
			task.wait(FRAME_TIME)
		end
	end)

	self.Janitor:Add(self.RagdollBinder:ObserveInstance(self.Object, function(Class)
		if not Class then
			self.LastRagdollTime = os.clock()
			self.ShouldRagdoll.Value = false
		end
	end), true)

	return self
end

function BindableRagdollHumanoidOnFall:__tostring()
	return "BindableRagdollHumanoidOnFall"
end

table.freeze(BindableRagdollHumanoidOnFall)
return BindableRagdollHumanoidOnFall
