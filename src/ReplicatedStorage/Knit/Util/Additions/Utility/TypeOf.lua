local function TypeOf(Object)
	local Type = typeof(Object)
	if Type == "table" then
		local Metatable = getmetatable(Object)
		if type(Metatable) == "table" then
			local ClassName = Metatable.ClassName or Metatable.__type
			if ClassName ~= nil then
				return ClassName
			end
		end
	end

	return Type
end

return TypeOf
