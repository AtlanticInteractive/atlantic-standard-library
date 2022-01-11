--[=[
	Helper methods for cooldown. See [RxCooldownUtility] for [Rx] utilities.
	@class CooldownUtility
]=]

local BinderUtility = require(script.Parent.Parent.Utility.BinderUtility)
local CooldownUtility = {}

--[=[
	Creates a new Roblox instance representing a cooldown.
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@param length number
	@return Instance
]=]
function CooldownUtility.Create(CooldownBinder, Parent, Length)
	assert(CooldownBinder, "Bad cooldownBinder")
	assert(typeof(Parent) == "Instance", "Bad parent")
	assert(type(Length) == "number", "Bad length")
	assert(Length > 0, "Bad length")

	local Cooldown = Instance.new("NumberValue")
	Cooldown.Value = Length
	Cooldown.Name = "Cooldown"

	CooldownBinder:Bind(Cooldown)

	Cooldown.Parent = Parent
	return Cooldown
end

--[=[
	Finds a cooldown in a parent.
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@return Cooldown? | CooldownClient?
]=]
function CooldownUtility.FindCooldown(CooldownBinder, Parent)
	assert(CooldownBinder, "Bad cooldownBinder")
	assert(typeof(Parent) == "Instance", "Bad parent")
	return BinderUtility.FindFirstChild(CooldownBinder, Parent)
end

--[=[
	Makes a copy of the cooldown
	@param cooldown Instance
	@return Instance
]=]
function CooldownUtility.Clone(Cooldown)
	assert(typeof(Cooldown) == "Instance", "Bad cooldown")
	return Cooldown:Clone()
end

table.freeze(CooldownUtility)
return CooldownUtility
