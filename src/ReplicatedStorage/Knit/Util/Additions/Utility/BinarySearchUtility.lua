--[=[
	Binary search implementation for Roblox in pure Lua
	@class BinarySearchUtility
]=]

local BinarySearchUtility = {}

--[=[
	```
	if t lands within the domain of two spans of time
		t = 5
		[3   5][5   7]
		          ^ picks this one
	```

	@param list {T}
	@param t number
	@return number
	@return number
]=]
function BinarySearchUtility.SpanSearch(list, t)
	local l = 1
	local h = #list

	if h < l then
		return nil, nil
	elseif t < list[l] then
		return nil, l
	elseif list[h] < t then
		return h, nil
	elseif l == h then
		return l, nil
	end

	while 1 < h - l do
		local m = math.floor((l + h) / 2)
		if t < list[m] then
			h = m
		else
			l = m
		end
	end

	return l, h
end

--[=[
	Same as searching a span, but uses a list of nodes

	@param list { TNode }
	@param index string
	@param t number
	@return number
	@return number
]=]
function BinarySearchUtility.SpanSearchNodes(list, index, t)
	local l = 1
	local h = #list

	if h < l then
		return nil, nil
	elseif t < list[l][index] then
		return nil, l
	elseif list[h][index] < t then
		return h, nil
	elseif l == h then
		return l, nil
	end

	while 1 < h - l do
		local m = math.floor((l + h) / 2)
		if t < list[m][index] then
			h = m
		else
			l = m
		end
	end

	return l, h
end

--[=[
	Same as span search, but uses an indexFunc to retrieve the index
	@param n number
	@param indexFunc (number) -> number
	@param t number
	@return number
	@return number
]=]
function BinarySearchUtility.SpanSearchAnything(n, indexFunc, t)
	local l = 1
	local h = n

	if h < l then
		return nil, nil
	elseif t < indexFunc(l) then
		return nil, l
	elseif indexFunc(h) < t then
		return h, nil
	elseif l == h then
		return l, nil
	end

	while 1 < h - l do
		local m = math.floor((l + h) / 2)
		if t < indexFunc(m) then
			h = m
		else
			l = m
		end
	end

	return l, h
end

table.freeze(BinarySearchUtility)
return BinarySearchUtility
