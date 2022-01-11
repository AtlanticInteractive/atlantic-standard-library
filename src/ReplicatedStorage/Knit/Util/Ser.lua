-- Ser
-- Stephen Leitnick
-- August 28, 2020

--[[
	Ser is a serialization/deserialization utility module that is used
	by Knit to automatically serialize/deserialize values passing
	through remote functions and remote events.

	Ser.Classes = {
		[ClassName] = {
			Serialize = (value) -> serializedValue
			Deserialize = (value) => deserializedValue
		}
	}

	Ser.SerializeArgs(...)            -> table
	Ser.SerializeArgsAndUnpack(...)   -> Tuple
	Ser.DeserializeArgs(...)          -> table
	Ser.DeserializeArgsAndUnpack(...) -> Tuple
	Ser.Serialize(value: any)         -> any
	Ser.Deserialize(value: any)       -> any
	Ser.UnpackArgs(args: table)       -> Tuple
--]]

local Debug = require(script.Parent.Additions.Debugging.Debug)
local Enumeration = require(script.Parent.Additions.Enumeration)
local Option = require(script.Parent.Option)

local Ser = {}

Ser.Classes = {
	Option = {
		Deserialize = Option.Deserialize;
		Serialize = function(SerializeOption)
			return SerializeOption:Serialize()
		end;
	};

	Enumeration = {
		Deserialize = function(EnumerationData)
			local EnumerationObject = Debug.Assert(Enumeration[EnumerationData.EnumerationType], "Invalid EnumerationType %q", EnumerationData.EnumerationType)
			return Debug.Assert(EnumerationObject:Cast(EnumerationData.Value))
		end;
	};
}

local function GetEnumerationType(Argument)
	return Argument.EnumerationType
end

local function GetClassName(Argument)
	return Argument.ClassName
end

function Ser.SerializeArgs(...)
	local Arguments = table.pack(...)
	for Index, Argument in ipairs(Arguments) do
		local TypeOf = typeof(Argument)
		if TypeOf == "table" then
			local Success, ClassName = pcall(GetClassName, Argument)
			if Success and ClassName then
				local Serializer = Ser.Classes[ClassName]
				if Serializer then
					Arguments[Index] = Serializer.Serialize(Argument)
				end
			end
		elseif TypeOf == "userdata" then
			local Success, EnumerationType = pcall(GetEnumerationType, Argument)
			if Success then
				Arguments[Index] = {
					ClassName = "Enumeration";
					EnumerationType = tostring(EnumerationType);
					Value = Argument.Name;
				}
			end
		end
	end

	return Arguments
end

function Ser.SerializeArgsAndUnpack(...)
	local Arguments = Ser.SerializeArgs(...)
	return table.unpack(Arguments, 1, Arguments.n)
end

function Ser.DeserializeArgs(...)
	local Arguments = table.pack(...)
	for Index, Argument in ipairs(Arguments) do
		if type(Argument) == "table" then
			local Serializer = Ser.Classes[Argument.ClassName]
			if Serializer then
				Arguments[Index] = Serializer.Deserialize(Argument)
			end
		end
	end

	return Arguments
end

function Ser.DeserializeArgsAndUnpack(...)
	local Arguments = Ser.DeserializeArgs(...)
	return table.unpack(Arguments, 1, Arguments.n)
end

function Ser.Serialize(Value)
	local TypeOf = typeof(Value)
	if TypeOf == "table" then
		local Success, ClassName = pcall(GetClassName, Value)
		if Success and ClassName then
			local Serializer = Ser.Classes[ClassName]
			if Serializer then
				return Serializer.Serialize(Value)
			end
		end
	elseif TypeOf == "userdata" then
		local Success, EnumerationType = pcall(GetEnumerationType, Value)
		if Success then
			return {
				ClassName = "Enumeration";
				EnumerationType = tostring(EnumerationType);
				Value = Value.Name;
			}
		end
	end

	return Value
end

function Ser.Deserialize(Value)
	if type(Value) == "table" then
		local Serializer = Ser.Classes[Value.ClassName]
		if Serializer then
			return Serializer.Deserialize(Value)
		end
	end

	return Value
end

function Ser.UnpackArgs(Arguments)
	return table.unpack(Arguments, 1, Arguments.n)
end

table.freeze(Ser)
return Ser
