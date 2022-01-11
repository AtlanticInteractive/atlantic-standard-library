--[=[
	[Observable] utilities for [Cooldown] class.
	@class RxCooldownUtility
]=]

local RxBinderUtility = require(script.Parent.Parent.Vendor.Nevermore.RxBinderUtility)
local RxCooldownUtility = {}

--[=[
	Observes a cooldown
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@return Observable<Brio<Cooldown | CooldownClient>>
]=]
function RxCooldownUtility.ObserveCooldownBrio(CooldownBinder, Parent)
	return RxBinderUtility.ObserveBoundChildClassBrio(CooldownBinder, Parent)
end

table.freeze(RxCooldownUtility)
return RxCooldownUtility
