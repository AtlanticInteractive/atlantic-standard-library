local BaseMotor = require(script.Parent.BaseMotor)
local Debug = require(script.Parent.Parent.Parent.Debugging.Debug)
local Fmt = require(script.Parent.Parent.Parent.Debugging.Fmt)
local IsMotor = require(script.Parent.IsMotor)
local SingleMotor = require(script.Parent.SingleMotor)

local GroupMotor = setmetatable({}, BaseMotor)
GroupMotor.ClassName = "GroupMotor"
GroupMotor.__index = GroupMotor

local function ToMotor(Value)
	if IsMotor(Value) then
		return Value
	end

	local ValueType = typeof(Value)

	if ValueType == "number" then
		return SingleMotor.new(Value, false)
	elseif ValueType == "table" then
		return GroupMotor.new(Value, false)
	end

	error(Fmt("Unable to convert {:?} to motor; type {} is unsupported", Value, ValueType), 2)
end

function GroupMotor.new(InitialValues, UseImplicitConnections)
	Debug.Assert(type(InitialValues) == "table", "initialValues must be a table!")
	local self = setmetatable(BaseMotor.new(), GroupMotor)

	if UseImplicitConnections ~= nil then
		self._UseImplicitConnections = UseImplicitConnections
	else
		self._UseImplicitConnections = true
	end

	self._Complete = true
	self._Motors = {}

	for Key, Value in next, InitialValues do
		self._Motors[Key] = ToMotor(Value)
	end

	return self
end

function GroupMotor:Step(DeltaTime)
	if self._Complete then
		return true
	end

	local AllMotorsComplete = true

	for _, Motor in next, self._Motors do
		local Complete = Motor:Step(DeltaTime)
		if not Complete then
			-- If any of the sub-motors are incomplete, the group motor will not be complete either
			AllMotorsComplete = false
		end
	end

	self._OnStep:Fire(self:GetValue())

	if AllMotorsComplete then
		if self._UseImplicitConnections then
			self:Stop()
		end

		self._Complete = true
		self._OnComplete:Fire()
	end

	return AllMotorsComplete
end

function GroupMotor:SetGoal(Goals)
	self._Complete = false
	self._OnStart:Fire()

	for Key, Goal in next, Goals do
		local Motor = Debug.Assert(self._Motors[Key], Fmt("Unknown motor for key {}", Key))
		Motor:SetGoal(Goal)
	end

	if self._UseImplicitConnections then
		self:Start()
	end
end

function GroupMotor:GetValue()
	local Values = {}
	for Key, Motor in next, self._Motors do
		Values[Key] = Motor:GetValue()
	end

	return Values
end

function GroupMotor:__tostring()
	return "Motor(Group)"
end

return GroupMotor
