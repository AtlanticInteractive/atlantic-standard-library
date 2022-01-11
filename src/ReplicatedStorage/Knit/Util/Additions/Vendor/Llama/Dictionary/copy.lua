local t = require(script.Parent.Parent.t)

local validate = t.table

local function copy(dictionary)
	assert(validate(dictionary))

	local new = {}

	for key, value in next, dictionary do
		new[key] = value
	end

	return new
end

return copy
