--[=[
	Represents a cooldown state with a time limit. See [CooldownBase] for more API.

	@server
	@class Cooldown
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttributeUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.AttributeUtility)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)
local CooldownBase = require(ReplicatedStorage.Knit.Util.Additions.Cooldown.CooldownBase)
local GetService = require(ReplicatedStorage.Knit.Util.GetService)

local Cooldown = setmetatable({}, CooldownBase)
Cooldown.ClassName = "Cooldown"
Cooldown.__index = Cooldown

--[=[
	Constructs a new cooldown. Should be done via [CooldownBindersServer]. To create an
	instance of this in Roblox, see [CooldownUtils.create].

	@param obj NumberValue
	@return Cooldown
]=]
function Cooldown.new(Object: NumberValue)
	local self = setmetatable(CooldownBase.new(Object), Cooldown)

	local CurrentTime = GetService.Default("TimeSyncService"):GetTime()
	local StartTime = AttributeUtility.InitializeAttribute(self.Object, Constants.COOLDOWN_CONSTANTS.COOLDOWN_START_TIME_ATTRIBUTE, CurrentTime)

	-- Delay for cooldown time
	-- TODO: Handle start tme changing
	task.delay(self.Object.Value + StartTime - CurrentTime, function()
		if self.Destroy then
			self.Object:Destroy()
		end
	end)

	return self
end

function Cooldown:__tostring()
	return "Cooldown"
end

table.freeze(Cooldown)
return Cooldown
