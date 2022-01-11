--[=[
	Stack of values that allows multiple systems to enable or disable a state.

	```lua
	local disabledStack = StateStack.new()
	print(disabledStack:GetState()) --> false

	disabledStack.Changed:Connect(function()
		print("From changed event we have state: ", disabledStack:GetState())
	end)

	local cancel = disabledStack:PushState() --> From changed event we have state: true
	print(disabledStack:GetState()) --> true

	cancel()  --> From changed event we have state: true
	print(disabledStack:GetState()) --> false

	disabledStack:Destroy()
	```

	@class StateStack
]=]

local BaseObject = require(script.Parent.BaseObject)
local ValueObject = require(script.Parent.ValueObject)

local StateStack = setmetatable({}, BaseObject)
StateStack.ClassName = "StateStack"
StateStack.__index = StateStack

--[=[
	Constructs a new StateStack.
	@return StateStack
]=]
function StateStack.new()
	local self = setmetatable(BaseObject.new(), StateStack)

	self.State = self.Janitor:Add(ValueObject.new(false), "Destroy")
	self.StateStack = {}

	--[=[
	Fires with the new state
	@prop Changed Signal<T>
	@within StateStack
]=]
	self.Changed = self.State.Changed

	return self
end

--[=[
	Gets the current state
	@return T?
]=]
function StateStack:GetState()
	return self.State.Value
end

--[=[
	Observes the current value of stack
	@return Observable<T?>
]=]
function StateStack:Observe()
	return self.State:Observe()
end

--[=[
	Pushes the current state onto the stack
	@param state T?
	@return function -- Cleanup function to invoke
]=]
function StateStack:PushState(State)
	if State == nil then
		State = true
	end

	local Data = {State}
	table.insert(self.StateStack, Data)

	self:UpdateState()

	return function()
		if self.Destroy then
			self:PopState(Data)
		end
	end
end

function StateStack:PopState(Data)
	local Index = table.find(self.StateStack, Data)
	if Index then
		table.remove(self.StateStack, Index)
		self:UpdateState()
	else
		warn("[StateStack] - Failed to find index")
	end
end

function StateStack:UpdateState()
	local _, Data = next(self.StateStack)
	if Data == nil then
		if type(self.State.Value) == "boolean" then
			self.State.Value = false
		else
			self.State.Value = nil
		end
	else
		self.State.Value = Data[1]
	end
end

function StateStack:__tostring()
	return "StateStack"
end

table.freeze(StateStack)

--[=[
	Cleans up the StateStack and sets the metatable to nil.

	:::tip
	Be sure to call this to clean up the state stack!
	:::
	@method Destroy
	@within StateStack
]=]

return StateStack
