-- Shake
-- Stephen Leitnick
-- December 09, 2021

local RunService = game:GetService("RunService")
local Janitor = require(script.Parent.Janitor)

--[=[
	@within Shake
	@type UpdateCallbackFn () -> (position: Vector3, rotation: Vector3, completed: boolean)
]=]
type UpdateFunction = (Position: Vector3, Rotation: Vector3, IsComplete: boolean) -> ()

local RandomLib = Random.new(os.clock() % 1 * 1E7)
local RenderId = 0

--[=[
	@class Shake
	Create realistic shake effects, such as camera or object shakes.

	Creating a shake is very simple with this module. For every shake,
	simply create a shake instance by calling `Shake.new()`. From
	there, configure the shake however desired. Once configured,
	call `shake:Start()` and then bind a function to it with either
	`shake:OnSignal(...)` or `shake:BindToRenderStep(...)`.

	The shake will output its values to the connected function, and then
	automatically stop and clean up its connections once completed.

	Shake instances can be reused indefinitely. However, only one shake
	operation per instance can be running. If more than one is needed
	of the same configuration, simply call `shake:Clone()` to duplicate
	it.

	Example of a simple camera shake:
	```lua
	local priority = Enum.RenderPriority.Last.Value

	local shake = Shake.new()
	shake.FadeInTime = 0
	shake.Frequency = 0.1
	shake.Amplitude = 5
	shake.RotationInfluence = Vector3.new(0.1, 0.1, 0.1)

	shake:Start()
	shake:BindToRenderStep(Shake.NextRenderName(), priority, function(pos, rot, isDone)
		camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
	end)
	```

	Shakes will automatically stop once the shake has been completed. Shakes can
	also be used continuously if the `Sustain` property is set to `true`.

	Here are some more helpful configuration examples:

	```lua
	local shake = Shake.new()

	-- The magnitude of the shake. Larger numbers means larger shakes.
	shake.Amplitude = 5

	-- The speed of the shake. Smaller frequencies mean faster shakes.
	shake.Frequency = 0.1

	-- Fade-in time before max amplitude shake. Set to 0 for immediate shake.
	shake.FadeInTime = 0

	-- Fade-out time. Set to 0 for immediate cutoff.
	shake.FadeOutTime = 0

	-- How long the shake sustains full amplitude before fading out
	shake.SustainTime = 1

	-- Set to true to never end the shake. Call shake:StopSustain() to start the fade-out.
	shake.Sustain = true

	-- Multiplies against the shake vector to control the final amplitude of the position.
	-- Can be seen internally as: position = shakeVector * fadeInOut * positionInfluence
	shake.PositionInfluence = Vector3.new(1, 1, 1)

	-- Multiplies against the shake vector to control the final amplitude of the rotation.
	-- Can be seen internally as: position = shakeVector * fadeInOut * rotationInfluence
	shake.RotationInfluence = Vector3.new(0.1, 0.1, 0.1)

	```
]=]
local Shake = {}
Shake.ClassName = "Shake"
Shake.__index = Shake

--[=[
	@within Shake
	@prop Amplitude number
	Amplitude of the overall shake. For instance, an amplitude of `3` would mean the
	peak magnitude for the outputted shake vectors would be about `3`.

	Defaults to `1`.
]=]

--[=[
	@within Shake
	@prop Frequency number
	Frequency of the overall shake. This changes how slow or fast the
	shake occurs.

	Defaults to `1`.
]=]

--[=[
	@within Shake
	@prop FadeInTime number
	How long it takes for the shake to fade in, measured in seconds.

	Defaults to `1`.
]=]

--[=[
	@within Shake
	@prop FadeOutTime number
	How long it takes for the shake to fade out, measured in seconds.

	Defaults to `1`.
]=]

--[=[
	@within Shake
	@prop SustainTime number
	How long it takes for the shake sustains itself after fading in and
	before fading out.

	To sustain a shake indefinitely, set `Sustain`
	to `true`, and call the `StopSustain()` method to stop the sustain
	and fade out the shake effect.

	Defaults to `0`.
]=]

--[=[
	@within Shake
	@prop Sustain boolean
	If `true`, the shake will sustain itself indefinitely once it fades
	in. If `StopSustain()` is called, the sustain will end and the shake
	will fade out based on the `FadeOutTime`.

	Defaults to `false`.
]=]

--[=[
	@within Shake
	@prop PositionInfluence Vector3
	This is similar to `Amplitude` but multiplies against each axis
	of the resultant shake vector, and only affects the position vector.

	Defaults to `Vector3.one`.
]=]

--[=[
	@within Shake
	@prop RotationInfluence Vector3
	This is similar to `Amplitude` but multiplies against each axis
	of the resultant shake vector, and only affects the rotation vector.

	Defaults to `Vector3.one`.
]=]

--[=[
	@within Shake
	@prop TimeFunction () -> number
	The function used to get the current time. This defaults to
	`time` during runtime, and `os.clock` otherwise. Usually this
	will not need to be set, but it can be optionally configured
	if desired.
]=]

--[=[
	@within Shake
	@prop NoiseFunction (X: number, Y: number) -> number
	The function used to get the 2D noise. This defaults to `math.noise`.
]=]

--[=[
	@return Shake
	Construct a new Shake instance.
]=]
function Shake.new()
	local self = setmetatable({}, Shake)
	self.Amplitude = 1
	self.FadeInTime = 1
	self.FadeOutTime = 1
	self.Frequency = 1
	self.NoiseFunction = math.noise
	self.PositionInfluence = Vector3.new(1, 1, 1)
	self.RotationInfluence = Vector3.new(1, 1, 1)
	self.Sustain = false
	self.SustainTime = 0
	self.TimeFunction = if RunService:IsRunning() then time else os.clock

	self._timeOffset = RandomLib:NextNumber(-1e9, 1e9)
	self._startTime = 0
	self._janitor = Janitor.new()
	self._running = false
	return self
end

--[=[
	@param vector Vector3
	@param distance number
	@return Vector3
	Apply an inverse square intensity multiplier to the given vector based on the
	distance away from some source. This can be used to simulate shake intensity
	based on the distance the shake is occurring from some source.

	For instance, if the shake is caused by an explosion in the game, the shake
	can be calculated as such:

	```lua
	local function Explosion(positionOfExplosion: Vector3)

		local cam = workspace.CurrentCamera
		local renderPriority = Enum.RenderPriority.Last.Value

		local shake = Shake.new()
		-- Set shake properties here

		local function ExplosionShake(pos: Vector3, rot: Vector3)
			local distance = (cam.CFrame.Position - positionOfExplosion).Magnitude
			pos = Shake.InverseSquare(pos, distance)
			rot = Shake.InverseSquare(rot, distance)
			cam.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
		end

		shake:BindToRenderStep("ExplosionShake", renderPriority, ExplosionShake)

	end
	```
]=]
function Shake.InverseSquare(shake: Vector3, distance: number): Vector3
	if distance < 1 then
		distance = 1
	end

	local intensity = 1 / (distance * distance)
	return shake * intensity
end

--[=[
	@return string
	Returns a unique render name for every call, which can
	be used with the `BindToRenderStep` method optionally.

	```lua
	shake:BindToRenderStep(Shake.NextRenderName(), ...)
	```
]=]
function Shake.NextRenderName(): string
	RenderId += 1
	return string.format("__shake_%.4i__", RenderId)
end

--[=[
	Start the shake effect.

	:::note
	This **must** be called before calling `Update`. As such, it should also be
	called once before or after calling `OnSignal` or `BindToRenderStep` methods.
	:::
]=]
function Shake:Start()
	self._startTime = self.TimeFunction()
	self._running = true
	self._janitor:Add(function()
		self._running = false
	end, true)
end

--[=[
	Stops the shake effect. If using `OnSignal` or `BindToRenderStep`, those bound
	functions will be disconnected/unbound.

	`Stop` is automatically called when the shake effect is completed _or_ when the
	`Destroy` method is called.
]=]
function Shake:Stop()
	self._janitor:Cleanup()
end

--[=[
	@return boolean
	Returns `true` if the shake instance is currently running,
	otherwise returns `false`.
]=]
function Shake:IsShaking(): boolean
	return self._running
end

--[=[
	Schedules a sustained shake to stop. This works by setting the
	`Sustain` field to `false` and letting the shake effect fade out
	based on the `FadeOutTime` field.
]=]
function Shake:StopSustain()
	local now = self.TimeFunction()
	self.Sustain = false
	self.SustainTime = now - self._startTime - self.FadeInTime
end

--[=[
	@return (position: Vector3, rotation: Vector3, completed: boolean)
	Calculates the current shake vector. This should be continuously
	called inside a loop, such as `RunService.Heartbeat`. Alternatively,
	`OnSignal` or `BindToRenderStep` can be used to automatically call
	this function.

	Returns a tuple of three values:
	1. `position: Vector3` - Position shake offset
	2. `rotation: Vector3` - Rotation shake offset
	3. `completed: boolean` - Flag indicating if the shake is finished

	```lua
	local hb
	hb = RunService.Heartbeat:Connect(function()
		local offsetPosition, offsetRotation, isDone = shake:Update()
		if isDone then
			hb:Disconnect()
		end
		-- Use `offsetPosition` and `offsetRotation` here
	end)
	```
]=]
function Shake:Update(): (Vector3, Vector3, boolean)
	local NoiseFunction = self.NoiseFunction

	local done = false

	local now = self.TimeFunction()
	local dur = now - self._startTime

	local noiseInput = ((now + self._timeOffset) / self.Frequency) % 1000000

	local multiplierFadeIn = 1
	local multiplierFadeOut = 1
	if dur < self.FadeInTime then
		multiplierFadeIn = dur / self.FadeInTime
	end

	if dur > self.FadeInTime + self.SustainTime then
		multiplierFadeOut = 1 - (dur - self.FadeInTime - self.SustainTime) / self.FadeOutTime
		if not self.Sustain and dur >= self.FadeInTime + self.SustainTime + self.FadeOutTime then
			done = true
		end
	end

	-- stylua: ignore
	local offset = Vector3.new(
		NoiseFunction(noiseInput, 0) / 2,
		NoiseFunction(0, noiseInput) / 2,
		NoiseFunction(noiseInput, noiseInput) / 2
	) * self.Amplitude * math.min(multiplierFadeIn, multiplierFadeOut)

	if done then
		self:Stop()
	end

	return self.PositionInfluence * offset, self.RotationInfluence * offset, done
end

--[=[
	@param signal Signal | RBXScriptSignal
	@param callbackFn UpdateCallbackFn
	@return Connection | RBXScriptConnection

	Bind the `Update` method to a signal. For instance, this can be used
	to connect to `RunService.Heartbeat`.

	All connections are cleaned up when the shake instance is stopped
	or destroyed.

	```lua
	local function SomeShake(pos: Vector3, rot: Vector3, completed: boolean)
		-- Shake
	end

	shake:OnSignal(RunService.Heartbeat, SomeShake)
	```
]=]
function Shake:OnSignal(signal, callbackFn: UpdateFunction)
	return self._janitor:Add(signal:Connect(function()
		callbackFn(self:Update())
	end), "Disconnect")
end

--[=[
	@param name string -- Name passed to `RunService:BindToRenderStep`
	@param priority number -- Priority passed to `RunService:BindToRenderStep`
	@param callbackFn UpdateCallbackFn

	Bind the `Update` method to RenderStep.

	All bond functions are cleaned up when the shake instance is stopped
	or destroyed.

	```lua
	local renderPriority = Enum.RenderPriority.Camera.Value

	local function SomeShake(pos: Vector3, rot: Vector3, completed: boolean)
		-- Shake
	end

	shake:BindToRenderStep("SomeShake", renderPriority, SomeShake)
	```
]=]
function Shake:BindToRenderStep(name: string, priority: number, callbackFn: UpdateFunction)
	RunService:BindToRenderStep(name, priority, function()
		callbackFn(self:Update())
	end)

	self._janitor:Add(function()
		RunService:UnbindFromRenderStep(name)
	end, true)
end

local cloneFields = {"Amplitude", "FadeInTime", "FadeOutTime", "Frequency", "NoiseFunction", "PositionInfluence", "RotationInfluence", "Sustain", "SustainTime", "TimeFunction"}

--[=[
	@return Shake
	Creates a new shake with identical properties as
	this one. This does _not_ clone over playing state,
	and thus the cloned instance will be in a stopped
	state.

	A use-case for using `Clone` would be to create a module
	with a list of shake presets. These presets can be cloned
	when desired for use. For instance, there might be presets
	for explosions, recoil, or earthquakes.

	```lua
	--------------------------------------
	-- Example preset module
	local ShakePresets = {}

	local explosion = Shake.new()
	-- Configure `explosion` shake here
	ShakePresets.Explosion = explosion

	return ShakePresets
	--------------------------------------

	-- Use the module:
	local ShakePresets = require(somewhere.ShakePresets)
	local explosionShake = ShakePresets.Explosion:Clone()
	```
]=]
function Shake:Clone()
	local shake = Shake.new()
	for _, field in ipairs(cloneFields) do
		shake[field] = self[field]
	end

	return shake
end

--[=[
	Destroy the Shake instance. Will call `Stop()`.
]=]
function Shake:Destroy()
	self:Stop()
	setmetatable(self, nil)
end

return Shake
