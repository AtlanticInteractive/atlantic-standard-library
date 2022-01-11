--[=[
	Handles cooldown on the client. See [CooldownBase] for details.

	@client
	@class CooldownClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CooldownBase = require(ReplicatedStorage.Knit.Util.Additions.Cooldown.CooldownBase)

local Cooldown = setmetatable({}, CooldownBase)
Cooldown.ClassName = "CooldownClient"
Cooldown.__index = Cooldown

--[=[
	Constructs a new cooldown. Should be done via [CooldownBindersClient]. To create an
	instance of this in Roblox, see [CooldownUtility.Create].

	@param obj NumberValue
	@return Cooldown
]=]
function Cooldown.new(Object: NumberValue)
	return setmetatable(CooldownBase.new(Object), Cooldown)
end

function Cooldown:__tostring()
	return "CooldownClient"
end

table.freeze(Cooldown)
return Cooldown
