local Brio = require(script.Parent.Brio)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local ValueObject = require(script.Parent.Parent.Parent.Classes.ValueObject)

local ValueObjectUtility = {}

type ValueObject<T> = ValueObject.ValueObject<T>

function ValueObjectUtility.SyncValue<T>(From: ValueObject<T>, To: ValueObject<T>)
	local SyncJanitor = Janitor.new()
	To.Value = From.Value

	SyncJanitor:Add(From.Changed:Connect(function()
		To.Value = From.Value
	end), "Disconnect")

	return SyncJanitor
end

function ValueObjectUtility.ObserveValue<T>(ObserveFrom: ValueObject<T>)
	assert(ValueObject.Is(ObserveFrom), "Bad ObserveFrom")

	return Observable.new(function(Subscription)
		if not ObserveFrom.Destroy then
			warn("[ValueObjectUtility.ObserveValue] - Connecting to dead ValueObject")
			-- No firing, we're dead
			return
		end

		local ObserveJanitor = Janitor.new()
		ObserveJanitor:Add(ObserveFrom.Changed:Connect(function()
			Subscription:Fire(ObserveFrom.Value)
		end), "Disconnect")

		Subscription:Fire(ObserveFrom.Value)
		return ObserveJanitor
	end)
end

function ValueObjectUtility.ObserveValueBrio<T>(ObserveFrom: ValueObject<T>)
	assert(ObserveFrom, "Bad valueObject")

	return Observable.new(function(Subscription)
		local ObserveJanitor = Janitor.new()
		local function Refire()
			Subscription:Fire(ObserveJanitor:Add(Brio.new(ObserveFrom.Value), "Destroy", "_LastBrio"))
		end

		ObserveJanitor:Add(ObserveFrom.Changed:Connect(Refire), "Disconnect")
		Refire()
		return ObserveJanitor
	end)
end

table.freeze(ValueObjectUtility)
return ValueObjectUtility
