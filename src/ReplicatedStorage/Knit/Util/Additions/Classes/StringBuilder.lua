local Fmt = require(script.Parent.Parent.Debugging.Fmt)

local StringBuilder = {}
StringBuilder.ClassName = "StringBuilder"
StringBuilder.__index = StringBuilder

function StringBuilder.new()
	return setmetatable({Length = 0}, StringBuilder)
end

function StringBuilder.FromPreallocation(Preallocate: number)
	local self = table.create(Preallocate)
	self.Length = 0
	return setmetatable(self, StringBuilder)
end

function StringBuilder:Append(Value: any)
	local Length = self.Length + 1
	self[Length] = tostring(Value)
	self.Length = Length
	return self
end

function StringBuilder:AppendString(Value: string)
	local Length = self.Length + 1
	self[Length] = Value
	self.Length = Length
	return self
end

function StringBuilder:AppendFmt(FormatString: string, ...)
	local Success, Value = pcall(Fmt, FormatString, ...)

	local Length = self.Length + 1
	self[Length] = if Success then Value else FormatString
	self.Length = Length
	return self
end

function StringBuilder:AppendFormat(FormatString: string, ...)
	local Success, Value = pcall(string.format, FormatString, ...)

	local Length = self.Length + 1
	self[Length] = if Success then Value else FormatString
	self.Length = Length
	return self
end

function StringBuilder:Prepend(Value: any)
	self.Length += 1
	table.insert(self, 1, tostring(Value))
	return self
end

function StringBuilder:PrependString(Value: string)
	self.Length += 1
	table.insert(self, 1, Value)
	return self
end

function StringBuilder:PrependFmt(FormatString: string, ...)
	local Success, Value = pcall(Fmt, FormatString, ...)
	self.Length += 1
	table.insert(self, 1, if Success then Value else FormatString)
	return self
end

function StringBuilder:PrependFormat(FormatString: string, ...)
	local Success, Value = pcall(string.format, FormatString, ...)
	self.Length += 1
	table.insert(self, 1, if Success then Value else FormatString)
	return self
end

function StringBuilder:Clear()
	table.clear(self)
	self.Length = 0
	return self
end

StringBuilder.ToString = table.concat
StringBuilder.__tostring = table.concat

export type StringBuilder = typeof(StringBuilder.new())
table.freeze(StringBuilder)
return StringBuilder
