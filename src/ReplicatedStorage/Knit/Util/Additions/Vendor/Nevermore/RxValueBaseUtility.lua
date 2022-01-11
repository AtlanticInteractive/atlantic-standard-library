---
-- @module RxValueBaseUtils
-- @author Quenty

local RxBrioUtils = require(script.Parent.RxBrioUtility)
local RxInstanceUtils = require(script.Parent.RxInstanceUtility)

local RxValueBaseUtils = {}

-- TODO: Handle default value/nothing there, instead of memory leaking!
function RxValueBaseUtils.Observe(parent, className, name)
	return RxInstanceUtils.ObserveLastNamedChildBrio(parent, className, name):Pipe({
		RxBrioUtils.SwitchMap(RxValueBaseUtils.ObserveValue);
	})
end

function RxValueBaseUtils.ObserveValue(valueObject)
	return RxInstanceUtils.ObserveProperty(valueObject, "Value")
end

return RxValueBaseUtils
