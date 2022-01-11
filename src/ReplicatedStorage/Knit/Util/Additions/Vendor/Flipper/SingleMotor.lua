local BaseMotor = require(script.Parent.BaseMotor)

local SingleMotor = setmetatable({}, BaseMotor)
SingleMotor.ClassName = "SingleMotor"
SingleMotor.__index = SingleMotor

function SingleMotor.new(InitialValue, UseImplicitConnections)
	assert(InitialValue, "Missing argument #1: initialValue")
	assert(type(InitialValue) == "number", "initialValue must be a number!")

	local self = setmetatable(BaseMotor.new(), SingleMotor)

	if UseImplicitConnections ~= nil then
		self._UseImplicitConnections = UseImplicitConnections
	else
		self._UseImplicitConnections = true
	end

	self._Goal = nil
	self._State = {
		complete = true;
		value = InitialValue;
	}

	return self
end

function SingleMotor:Step(DeltaTime)
	if self._State.complete then
		return true
	end

	local NewState = self._Goal:Step(self._State, DeltaTime)
	self._State = NewState
	self._OnStep:Fire(NewState.value)

	if NewState.complete then
		if self._UseImplicitConnections then
			self:Stop()
		end

		self._OnComplete:Fire()
	end

	return NewState.complete
end

function SingleMotor:GetValue()
	return self._State.value
end

function SingleMotor:SetGoal(Goal)
	self._State.complete = false
	self._Goal = Goal

	self._OnStart:Fire()

	if self._UseImplicitConnections then
		self:Start()
	end
end

function SingleMotor:__tostring()
	return "Motor(Single)"
end

return SingleMotor
