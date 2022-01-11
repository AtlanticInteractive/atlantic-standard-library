local indent = "\t" or "    "

local function prettyPrint(value, indentLevel)
	indentLevel = indentLevel or 0
	local output = {}

	if type(value) == "table" then
		table.insert(output, "{\n")

		for tableKey, tableValue in next, value do
			table.insert(output, string.rep(indent, indentLevel + 1))
			table.insert(output, tostring(tableKey))
			table.insert(output, " = ")

			table.insert(output, prettyPrint(tableValue, indentLevel + 1))
			table.insert(output, "\n")
		end

		table.insert(output, string.rep(indent, indentLevel))
		table.insert(output, "}")
	elseif type(value) == "string" then
		table.insert(output, string.format("%q", value))
		table.insert(output, " (string)")
	else
		table.insert(output, tostring(value))
		table.insert(output, " (")
		table.insert(output, typeof(value))
		table.insert(output, ")")
	end

	return table.concat(output)
end

return prettyPrint
