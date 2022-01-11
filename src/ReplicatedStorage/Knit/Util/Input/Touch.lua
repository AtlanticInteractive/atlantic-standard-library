-- Touch
-- Stephen Leitnick
-- March 14, 2021

local UserInputService = game:GetService("UserInputService")
local Janitor = require(script.Parent.Parent.Janitor)
local Signal = require(script.Parent.Parent.Signal)

--[=[
	@class Touch
	@client

	The Touch class is part of the Input package.

	```lua
	local Touch = require(packages.Input).Touch
	```
]=]
local Touch = {}
Touch.ClassName = "Touch"
Touch.__index = Touch

--[=[
	@within Touch
	@prop TouchTapInWorld Signal<(position: Vector2, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchTapInWorld](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchTapInWorld).
]=]
--[=[
	@within Touch
	@prop TouchPan Signal<(touchPositions: {Vector2}, totalTranslation: Vector2, velocity: Vector2, state: Enum.UserInputState, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchPan](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchPan).
]=]
--[=[
	@within Touch
	@prop TouchPinch Signal<(touchPositions: {Vector2}, scale: number, velocity: Vector2, state: Enum.UserInputState, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchPinch](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchPinch).
]=]

--[=[
	Constructs a new Touch input capturer.
]=]
function Touch.new()
	local self = setmetatable({}, Touch)

	self.Janitor = Janitor.new()

	self.TouchEnded = Signal.Wrap(UserInputService.TouchEnded, self.Janitor)
	self.TouchLongPress = Signal.Wrap(UserInputService.TouchLongPress, self.Janitor)
	self.TouchMoved = Signal.Wrap(UserInputService.TouchMoved, self.Janitor)
	self.TouchPan = Signal.Wrap(UserInputService.TouchPan, self.Janitor)
	self.TouchPinch = Signal.Wrap(UserInputService.TouchPinch, self.Janitor)
	self.TouchRotate = Signal.Wrap(UserInputService.TouchRotate, self.Janitor)
	self.TouchStarted = Signal.Wrap(UserInputService.TouchStarted, self.Janitor)
	self.TouchSwipe = Signal.Wrap(UserInputService.TouchSwipe, self.Janitor)
	self.TouchTap = Signal.Wrap(UserInputService.TouchTap, self.Janitor)
	self.TouchTapInWorld = Signal.Wrap(UserInputService.TouchTapInWorld, self.Janitor)

	return self
end

--[=[
	Destroys the Touch input capturer.
]=]
function Touch:Destroy()
	self.Janitor:Destroy()
end

function Touch:__tostring()
	return "Touch"
end

export type Touch = typeof(Touch.new())
table.freeze(Touch)
return Touch
