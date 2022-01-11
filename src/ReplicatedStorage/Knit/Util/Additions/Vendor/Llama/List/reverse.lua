local List = script.Parent

local Llama = List.Parent
local t = require(Llama.t)

local validate = t.table

local function reverse(list)
	assert(validate(list))

	local new = {}

	local back = #list + 1

	for i = 1, #list do
		new[i] = list[back - i]
	end

	return new
end

return reverse
