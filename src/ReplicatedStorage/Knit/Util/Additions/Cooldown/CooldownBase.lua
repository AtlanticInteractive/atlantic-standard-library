--[=[
	Base object for a cooldown. Provides calculation utilties.
	@class CooldownBase
]=]

local BaseObject = require(script.Parent.Parent.Classes.BaseObject)
local Constants = require(script.Parent.Parent.KnitConstants)
local GetControllerOrService = require(script.Parent.Parent.Parent.GetControllerOrService)
local Signal = require(script.Parent.Parent.Parent.Signal)

local CooldownBase = setmetatable({}, BaseObject)
CooldownBase.ClassName = "CooldownBase"
CooldownBase.__index = CooldownBase

--[=[
	Constructs a new Cooldown.
	@param obj NumberValue
	@return CooldownBase
]=]
function CooldownBase.new(Object: NumberValue)
	local self = setmetatable(BaseObject.new(Object), CooldownBase)
	self.TimeSyncService = GetControllerOrService.Default("TimeSync")

	--[=[
	Event that fires when the cooldown is done.
	@prop Done Signal<()>
	@within CooldownClient
]=]
	self.Done = Signal.new()
	self.Janitor:Add(function()
		self.Done:Fire()
		self.Done:Destroy()
	end, true)

	return self
end

--[=[
	Gets the Roblox instance of the cooldown.
	@return Instance
]=]
function CooldownBase:GetObject()
	return self.Object
end

--[=[
	Gets the time passed
	@return number?
]=]
function CooldownBase:GetTimePassed()
	local StartTime = self:GetStartTime()
	if not StartTime then
		return nil
	end

	return self.TimeSyncService:GetTime() - StartTime
end

--[=[
	Gets the time remaining
	@return number?
]=]
function CooldownBase:GetTimeRemaining()
	local EndTime = self:GetEndTime()
	if not EndTime then
		return nil
	end

	return math.max(0, EndTime - self.TimeSyncService:GetTime())
end

--[=[
	Gets the synchronized time stamp the cooldown is ending at
	@return number?
]=]
function CooldownBase:GetEndTime()
	local StartTime = self:GetStartTime()
	if not StartTime then
		return nil
	end

	return StartTime + self:GetLength()
end

--[=[
	Gets the synchronized time stamp the cooldown is starting at
	@return number?
]=]
function CooldownBase:GetStartTime()
	local StartTime = self.Object:GetAttribute(Constants.COOLDOWN_CONSTANTS.COOLDOWN_START_TIME_ATTRIBUTE)
	if type(StartTime) == "number" then
		return StartTime
	else
		return nil
	end
end

--[=[
	Gets the length of the cooldown
	@return number
]=]
function CooldownBase:GetLength()
	return self.Object.Value
end

function CooldownBase:__tostring()
	return "CooldownBase"
end

table.freeze(CooldownBase)
return CooldownBase
