local Observable = require(script.Parent.Parent.Vendor.Nevermore.Observable)
local Promise = require(script.Parent.Parent.Parent.Promise)
local Rx = require(script.Parent.Parent.Vendor.Nevermore.Rx)
local RxValueBaseUtility = require(script.Parent.Parent.Vendor.Nevermore.RxValueBaseUtility)
local ValueBaseUtility = require(script.Parent.Parent.Vendor.Nevermore.ValueBaseUtility)
local ValueObject = require(script.Parent.Parent.Classes.ValueObject)
local ValueObjectUtility = require(script.Parent.Parent.Vendor.Nevermore.ValueObjectUtility)

local function ToPropertyObservable(Value)
	if Observable.Is(Value) then
		return Value
	elseif typeof(Value) == "Instance" then
		-- IntValue, ObjectValue, et cetera
		if ValueBaseUtility.IsValueBase(Value) then
			return RxValueBaseUtility.ObserveValue(Value)
		end
	elseif type(Value) == "table" then
		if ValueObject.Is(Value) then
			return ValueObjectUtility.ObserveValue(Value)
		elseif Promise.Is(Value) then
			return Rx.FromPromise(Value)
		end
	end

	return nil
end

return ToPropertyObservable
