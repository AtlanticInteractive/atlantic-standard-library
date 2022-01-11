local RepeatCache = {}

local function StringRep(String: string, Amount: number)
	local StringCache = RepeatCache[String]
	if StringCache == nil then
		StringCache = {}
		RepeatCache[String] = StringCache
	end

	local RepeatString = StringCache[Amount]
	if RepeatString == nil then
		RepeatString = string.rep(String, Amount)
		StringCache[Amount] = RepeatString
	end

	return RepeatString
end

return StringRep
