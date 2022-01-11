--[=[
	Utility functions affecting Brios.
	@class BrioUtils
]=]

local Brio = require(script.Parent.Brio)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)

local BrioUtility = {}

type Brio<T> = Brio.Brio<T>

--[=[
	Clones a brio, such that it may be killed without affecting the original
	brio.

	@param CloneBrio Brio<T>
	@return Brio<T>
]=]
function BrioUtility.Clone<T>(CloneBrio: Brio<T>): Brio<T>
	assert(CloneBrio, "Bad brio")
	if CloneBrio:IsDead() then
		return Brio.DEAD
	end

	local NewBrio = Brio.new(CloneBrio:GetValue())
	NewBrio:ToJanitor():Add(CloneBrio:GetDiedSignal():Connect(function()
		NewBrio:Destroy()
	end), "Disconnect")

	return NewBrio
end

--[=[
	Returns a list of alive Brios only

	@param Brios {Brio<T>}
	@return {Brio<T>}
]=]
function BrioUtility.AliveOnly<T>(Brios: {Brio<T>}): {Brio<T>}
	local Alive = {}
	for _, CheckBrio in ipairs(Brios) do
		if not CheckBrio:IsDead() then
			table.insert(Alive, CheckBrio)
		end
	end

	return Alive
end

--[=[
	Returns the first alive Brio in a list

	@param Brios {Brio<T>}
	@return Brio<T>
]=]
function BrioUtility.FirstAlive<T>(Brios: {Brio<T>}): Brio<T>?
	for _, CheckBrio in ipairs(Brios) do
		if not CheckBrio:IsDead() then
			return CheckBrio
		end
	end

	return nil
end

--[=[
	Given a list of brios of brios, flattens that list into a brio with
	just one T value.

	@param BrioTable { any: Brio<Brio<T> | T>}
	@return Brio<{T}>
]=]
function BrioUtility.Flatten<T>(BrioTable: {[any]: Brio<Brio<T>> | T}): Brio<{T}>
	local NewValue = {}
	local Brios = {}

	for Key, CheckBrio in next, BrioTable do
		if Brio.Is(CheckBrio) then
			if CheckBrio:IsDead() then
				return Brio.DEAD
			else
				table.insert(Brios, CheckBrio)
				NewValue[Key] = CheckBrio:GetValue()
			end
		else
			NewValue[Key] = CheckBrio
		end
	end

	return BrioUtility.First(Brios, NewValue)
end

--[=[
	Returns a brio that dies whenever the first Brio in the list
	dies. The value of the Brio is the `...` value.

	@param Brios {Brio<T>}
	@param ... U
	@return Brio<U>
]=]
function BrioUtility.First<T, U>(Brios: {Brio<T>}, ...: U): Brio<U>
	for _, CheckBrio in ipairs(Brios) do
		if Brio.Is(CheckBrio) then
			if CheckBrio:IsDead() then
				return Brio.DEAD
			end
		end
	end

	local FirstJanitor = Janitor.new()
	local TopBrio = Brio.new(...)

	for _, CheckBrio in ipairs(Brios) do
		if Brio.Is(CheckBrio) then
			FirstJanitor:Add(CheckBrio:GetDiedSignal():Connect(function()
				TopBrio:Destroy()
			end), "Disconnect")
		end
	end

	FirstJanitor:Add(TopBrio:GetDiedSignal():Connect(function()
		FirstJanitor:Cleanup()
	end), "Disconnect")

	return TopBrio
end

--[=[
	Clones a brio, such that it may be killed without affecting the original
	brio.

	@since 3.6.0
	@param WithBrio Brio<T>
	@param ... U
	@return Brio<U>
]=]
function BrioUtility.WithOtherValues<T, U>(WithBrio: Brio<T>, ...: U): Brio<U>
	assert(WithBrio, "Bad brio")
	if WithBrio:IsDead() then
		return Brio.DEAD
	end

	local NewBrio = Brio.new(...)
	NewBrio:ToJanitor():Add(WithBrio:GetDiedSignal():Connect(function()
		NewBrio:Destroy()
	end), "Disconnect")

	return NewBrio
end

--[=[
	Makes a brio that is limited by the lifetime of its parent (but could be shorter)
	and has the new values given.

	@param ExtendBrio Brio<U>
	@param ... T
	@return Brio<T>
]=]
function BrioUtility.Extend<U, T>(ExtendBrio: Brio<U>, ...: T): Brio<T>
	if ExtendBrio:IsDead() then
		return Brio.DEAD
	end

	local Values = ExtendBrio._Values
	local OtherValues = table.pack(...)
	local Current = table.move(OtherValues, 1, OtherValues.n, Values.n + 1, table.move(Values, 1, Values.n, 1, table.create(Values.n + OtherValues.n)))

	local ExtendJanitor = Janitor.new()
	local NewBrio = Brio.new(table.unpack(Current, 1, Values.n + OtherValues.n))

	ExtendJanitor:Add(ExtendBrio:GetDiedSignal():Connect(function()
		NewBrio:Destroy()
	end), "Disconnect")

	ExtendJanitor:Add(NewBrio:GetDiedSignal():Connect(function()
		ExtendJanitor:Cleanup()
	end), "Disconnect")

	return NewBrio
end

--[=[
	Makes a brio that is limited by the lifetime of its parent (but could be shorter)
	and has the new values given at the beginning of the result

	@since 3.6.0
	@param PrependBrio Brio<U>
	@param ... T
	@return Brio<T>
]=]
function BrioUtility.Prepend<U, T>(PrependBrio: Brio<U>, ...: T): Brio<T>
	if PrependBrio:IsDead() then
		return Brio.DEAD
	end

	local Values = PrependBrio._Values
	local OtherValues = table.pack(...)
	local Current = table.move(OtherValues, 1, OtherValues.n, Values.n + 1, table.move(Values, 1, Values.n, 1, table.create(Values.n + OtherValues.n)))

	local PrependJanitor = Janitor.new()
	local NewBrio = Brio.new(table.unpack(Current, 1, Values.n + OtherValues.n))

	PrependJanitor:Add(PrependBrio:GetDiedSignal():Connect(function()
		NewBrio:Destroy()
	end), "Disconnect")

	PrependJanitor:Add(NewBrio:GetDiedSignal():Connect(function()
		PrependJanitor:Cleanup()
	end), "Disconnect")

	return NewBrio
end

--[=[
	Merges the existing brio value with the other brio

	@param MergeBrio Brio<{T}>
	@param OtherBrio Brio<{U}>
	@return Brio<{T | U}>
]=]
function BrioUtility.Merge<T, U>(MergeBrio: Brio<{T}>, OtherBrio: Brio<{U}>): Brio<{T | U}>
	assert(Brio.Is(MergeBrio), "Not a brio")
	assert(Brio.Is(OtherBrio), "Not a brio")

	if MergeBrio:IsDead() or OtherBrio:IsDead() then
		return Brio.DEAD
	end

	local Values = MergeBrio._Values
	local OtherValues = OtherBrio._Values
	local Current = table.move(OtherValues, 1, OtherValues.n, Values.n + 1, table.move(Values, 1, Values.n, 1, table.create(Values.n + OtherValues.n)))

	local MergeJanitor = Janitor.new()
	local NewBrio = Brio.new(table.unpack(Current, 1, Values.n + OtherValues.n))

	MergeJanitor:Add(MergeBrio:GetDiedSignal():Connect(function()
		NewBrio:Destroy()
	end), "Disconnect")

	MergeJanitor:Add(OtherBrio:GetDiedSignal():Connect(function()
		NewBrio:Destroy()
	end), "Disconnect")

	MergeJanitor:Add(NewBrio:GetDiedSignal():Connect(function()
		MergeJanitor:Cleanup()
	end), "Disconnect")

	return NewBrio
end

table.freeze(BrioUtility)
return BrioUtility
