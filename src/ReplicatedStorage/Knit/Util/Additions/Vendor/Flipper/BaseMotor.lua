local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Parent.Parent.Parent.Signal)

local NoOp = function() end

local BaseMotor = {}
BaseMotor.ClassName = "BaseMotor"
BaseMotor.__index = BaseMotor

function BaseMotor.new()
	return setmetatable({
		_OnComplete = Signal.new();
		_OnStart = Signal.new();
		_OnStep = Signal.new();
	}, BaseMotor)
end

function BaseMotor:OnStep(Function)
	return self._OnStep:Connect(Function)
end

function BaseMotor:OnStart(Function)
	return self._OnStart:Connect(Function)
end

function BaseMotor:OnComplete(Function)
	return self._OnComplete:Connect(Function)
end

function BaseMotor:Start()
	if not self._Connection then
		self._Connection = RunService.Heartbeat:Connect(function(DeltaTime)
			self:Step(DeltaTime)
		end)
	end
end

function BaseMotor:Stop()
	if self._Connection then
		self._Connection = self._Connection:Disconnect()
	end
end

function BaseMotor:Destroy()
	if self._Connection then
		self._Connection:Disconnect()
	end

	self._OnStep:Destroy()
	self._OnStart:Destroy()
	self._OnComplete:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

BaseMotor.Step = NoOp
BaseMotor.GetValue = NoOp
BaseMotor.SetGoal = NoOp

function BaseMotor:__tostring()
	return "Motor"
end

return BaseMotor
