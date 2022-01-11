local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local CustomCameraEffect = require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("Camera"):WaitForChild("Effects"):WaitForChild("CustomCameraEffect"))
local DefaultCamera = require(StarterPlayerScripts.Modules.Camera.Effects.DefaultCamera)
local ImpulseCamera = require(StarterPlayerScripts.Modules.Camera.Effects.ImpulseCamera)

local CameraStackController = Knit.CreateController({
	Name = "CameraStackController";
})

--[=[
	Prevents the default camera from being used
	@param doNotUseDefaultCamera boolean
]=]
function CameraStackController:SetDoNotUseDefaultCamera(DoNotUseDefaultCamera: boolean)
	self.DoNotUseDefaultCamera = DoNotUseDefaultCamera
end

--[=[
	Pushes a disable state onto the camera stack
	@return function -- Function to cancel disable
]=]
function CameraStackController:PushDisable()
	local DisabledKey = HttpService:GenerateGUID(false)
	self.DisabledSet[DisabledKey] = true

	return function()
		self.DisabledSet[DisabledKey] = nil
	end
end

--[=[
	Outputs the camera stack. Intended for diagnostics.
]=]
function CameraStackController:PrintCameraStack()
	for _, Value in next, self.Stack do
		print(tostring(type(Value) == "table" and Value.ClassName or tostring(Value)))
	end
end

--[=[
	Returns the default camera
	@return SummedCamera -- DefaultCamera + ImpulseCamera
]=]
function CameraStackController:GetDefaultCamera()
	return self.DefaultCamera
end

--[=[
	Returns the impulse camera. Useful for adding camera shake.

	Shaking the camera:
	```lua
	CameraStackController:GetImpulseCamera():Impulse(Vector3.new(0.25, 0, 0.25*(math.random()-0.5)))
	```

	You can also sum the impulse camera into another effect to layer the shake on top of the effect
	as desired.

	```lua
	-- Adding global custom camera shake to a custom camera effect
	local customCameraEffect = ...
	return (customCameraEffect + CameraStackController:GetImpulseCamera()):SetMode("Relative")
	```

	@return ImpulseCamera
]=]
function CameraStackController:GetImpulseCamera()
	return self.ImpulseCamera
end

--[=[
	Returns the default camera without any impulse cameras
	@return DefaultCamera
]=]
function CameraStackController:GetRawDefaultCamera()
	return self.RawDefaultCamera
end

--[=[
	Gets the camera current on the top of the stack
	@return CameraEffect
]=]
function CameraStackController:GetTopCamera()
	return self.Stack[#self.Stack]
end

--[=[
	Retrieves the top state off the stack at this time
	@return CameraState?
]=]
function CameraStackController:GetTopState()
	if #self.Stack > 10 then
		warn(string.format("[CameraStackController] - Stack is bigger than 10 in camerastackService (%d)", #self.Stack))
	end

	local TopState = self.Stack[#self.Stack]

	if type(TopState) == "table" then
		local State = TopState.CameraState or TopState
		if State then
			return State
		else
			warn("[CameraStackController] - No top state!")
		end
	else
		warn("[CameraStackController] - Bad type on top of stack")
	end
end

--[=[
	Returns a new camera state that retrieves the state below its set state.

	@return CustomCameraEffect -- Effect below
	@return (CameraState) -> () -- Function to set the state
]=]
function CameraStackController:GetNewStateBelow()
	local StateToUse = nil
	return CustomCameraEffect.new(function()
		local Index = table.find(self.Stack, StateToUse)
		if Index then
			local Below = self.Stack[Index - 1]
			if Below then
				return Below.CameraState or Below
			else
				warn("[CameraStackController] - Could not get state below, found current state. Returning default.")
				return self.Stack[1].CameraState
			end
		else
			warn(string.format("[CameraStackController] - Could not get state from %q, returning default", tostring(StateToUse)))
			return self.Stack[1].CameraState
		end
	end), function(NewStateToUse)
		StateToUse = NewStateToUse
	end
end

--[=[
	Retrieves the index of a state
	@param state CameraEffect
	@return number? -- index

]=]
function CameraStackController:GetIndex(State)
	return table.find(self.Stack, State)
end

--[=[
	Returns the current stack.

	:::warning
	Do not modify this stack, this is the raw memory of the stack
	:::

	@return { CameraState<T> }
]=]
function CameraStackController:GetStack()
	return self.Stack
end

--[=[
	Removes the state from the stack
	@param state CameraState
]=]
function CameraStackController:Remove(State)
	local Index = table.find(self.Stack, State)
	if Index then
		table.remove(self.Stack, Index)
	end
end

--[=[
	Adds the state from the stack
	@param state CameraState
]=]
function CameraStackController:Add(State)
	table.insert(self.Stack, State)
end

function CameraStackController:KnitInit()
	self.Stack = {}
	self.DisabledSet = {}

	-- Initialize default cameras
	self.RawDefaultCamera = DefaultCamera.new()
	self.ImpulseCamera = ImpulseCamera.new()
	self.DefaultCamera = (self.RawDefaultCamera + self.ImpulseCamera):SetMode("Relative")

	if self.DoNotUseDefaultCamera then
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

		-- TODO: Handle camera deleted too!
		Workspace.CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		end)
	else
		self.RawDefaultCamera:BindToRenderStep()
	end

	-- Add camera to stack
	self:Add(self.DefaultCamera)

	RunService:BindToRenderStep("CameraStackUpdateInternal", Enum.RenderPriority.Camera.Value + 75, function()
		debug.profilebegin("CameraStackUpdate")
		if next(self.DisabledSet) then
			return
		end

		local State = self:GetTopState()
		if State then
			State:Set(Workspace.CurrentCamera)
		end

		debug.profileend()
	end)
end

return CameraStackController
