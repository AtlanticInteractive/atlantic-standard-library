-- Keyboard
-- Stephen Leitnick
-- October 10, 2021

local UserInputService = game:GetService("UserInputService")
local Janitor = require(script.Parent.Parent.Janitor)
local Signal = require(script.Parent.Parent.Signal)

--[=[
	@class Keyboard
	@client

	The Keyboard class is part of the Input package.

	```lua
	local Keyboard = require(packages.Input).Keyboard
	```
]=]
local Keyboard = {}
Keyboard.ClassName = "Keyboard"
Keyboard.__index = Keyboard

--[=[
	@within Keyboard
	@prop KeyDown Signal<Enum.KeyCode>
	@tag Event
	Fired when a key is pressed.
	```lua
	keyboard.KeyDown:Connect(function(key: KeyCode)
		print("Key pressed", key)
	end)
	```
]=]
--[=[
	@within Keyboard
	@prop KeyUp Signal<Enum.KeyCode>
	@tag Event
	Fired when a key is released.
	```lua
	keyboard.KeyUp:Connect(function(key: KeyCode)
		print("Key released", key)
	end)
	```
]=]

--[=[
	@return Keyboard

	Constructs a new keyboard input capturer.

	```lua
	local keyboard = Keyboard.new()
	```
]=]
function Keyboard.new()
	local self = setmetatable({}, Keyboard)
	self.Janitor = Janitor.new()
	self.KeyDown = Signal.new(self.Janitor)
	self.KeyUp = Signal.new(self.Janitor)
	self:_setup()
	return self
end

--[=[
	@param keyCode Enum.KeyCode
	@return isDown: boolean

	Returns `true` if the key is down.

	```lua
	local w = keyboard:IsKeyDown(Enum.KeyCode.W)
	if w then ... end
	```
]=]
function Keyboard:IsKeyDown(keyCode: Enum.KeyCode)
	return UserInputService:IsKeyDown(keyCode)
end

--[=[
	@param keyCodeOne Enum.KeyCode
	@param keyCodeTwo Enum.KeyCode
	@return areKeysDown: boolean

	Returns `true` if both keys are down. Useful for key combinations.

	```lua
	local shiftA = keyboard:AreKeysDown(Enum.KeyCode.LeftShift, Enum.KeyCode.A)
	if shiftA then ... end
	```
]=]
function Keyboard:AreKeysDown(keyCodeOne: Enum.KeyCode, keyCodeTwo: Enum.KeyCode)
	return self:IsKeyDown(keyCodeOne) and self:IsKeyDown(keyCodeTwo)
end

function Keyboard:_setup()
	self.Janitor:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
			self.KeyDown:Fire(input.KeyCode)
		end
	end), "Disconnect")

	self.Janitor:Add(UserInputService.InputEnded:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
			self.KeyUp:Fire(input.KeyCode)
		end
	end), "Disconnect")
end

--[=[
	Destroy the keyboard input capturer.
]=]
function Keyboard:Destroy()
	self.Janitor:Destroy()
end

function Keyboard:__tostring()
	return "Keyboard"
end

export type Keyboard = typeof(Keyboard.new())
table.freeze(Keyboard)
return Keyboard
