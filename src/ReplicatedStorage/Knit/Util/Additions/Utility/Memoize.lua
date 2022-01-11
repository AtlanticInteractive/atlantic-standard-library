export type MemoizableFunction<IndexType, ReturnType> = (Index: IndexType) -> ReturnType

local function Memoize<IndexType, ReturnType>(Function: MemoizableFunction<IndexType, ReturnType>)
	local Cache = {}
	return function(Index: IndexType)
		local Value = Cache[Index]
		if Value == nil then
			Value = Function(Index)
			Cache[Index] = Value
		end

		return Value
	end
end

return Memoize
