local FastRequire = require(script.Parent.Parent.Utility.FastRequire)
local Promise = require(script.Parent.Parent.Parent.Promise)

local Debug = script.Parent.Debug
local Enumeration = script.Parent.Parent.Enumeration

local BuiltInTypes = {
	Bool = "boolean";
	Boolean = "boolean";
	Function = "function";
	Nil = "nil";
	Number = "number";
	String = "string";
	Table = "table";
	Thread = "thread";
	Userdata = "userdata";
	Vector = "vector";
}

local REPLACEMENT = "%1s"

local CustomTypes = {
	Any = function()
		return true
	end;

	Array = function(Array, Type, Callback, Castable)
		if Type ~= "table" then
			return false
		end

		local Size = #Array
		local Bool = false

		for Key, Value in next, Array do
			Bool = true
			if type(Key) ~= "number" or Key % 1 ~= 0 or Key < 1 or Key > Size then
				return false
			elseif Callback then
				local Success = Callback(Value)

				if Success then
					if Castable then
						Array[Key] = Success
					end
				else
					return false
				end
			end
		end

		return Bool
	end;

	Dictionary = function(Dictionary, Type, Callback, Castable)
		if Type ~= "table" then
			return false
		end

		local Bool = false

		for Key, Value in next, Dictionary do
			Bool = true
			if type(Key) == "number" then
				return false
			elseif Callback then
				local Success = Callback(Value)

				if Success then
					if Castable then
						Dictionary[Key] = Success
					end
				else
					return false
				end
			end
		end

		return Bool
	end;

	Table = function(Tab, Type, Callback, Castable)
		if Type ~= "table" then
			return false
		end

		if Callback then
			local Bool = false

			for Key, Value in next, Tab do
				Bool = true
				local Success = Callback(Value)

				if Success then
					if Castable then
						Tab[Key] = Success
					end
				else
					return false
				end
			end

			return Bool
		else
			return true
		end
	end;

	EmptyTable = function(Value, Type)
		return Type ~= "table" or next(Value) == nil
	end;

	NonNil = function(Value)
		return Value ~= nil
	end;

	Integer = function(Value, Type)
		return Type == "number" and Value % 1 == 0
	end;

	PositiveInteger = function(Value, Type)
		return Type == "number" and Value > 0 and Value % 1 == 0
	end;

	NegativeInteger = function(Value, Type)
		return Type == "number" and Value < 0 and Value % 1 == 0
	end;

	NonPositiveInteger = function(Value, Type)
		return Type == "number" and Value <= 0 and Value % 1 == 0
	end;

	NonNegativeInteger = function(Value, Type)
		return Type == "number" and Value >= 0 and Value % 1 == 0
	end;

	PositiveNumber = function(Value, Type)
		return Type == "number" and Value > 0
	end;

	NegativeNumber = function(Value, Type)
		return Type == "number" and Value < 0
	end;

	NonPositiveNumber = function(Value, Type)
		return Type == "number" and Value <= 0
	end;

	NonNegativeNumber = function(Value, Type)
		return Type == "number" and Value >= 0
	end;

	Truthy = function(Value)
		return Value and true or false
	end;

	Falsy = function(Value)
		return not Value
	end;

	Enum = function(_, Type)
		return Type == "Enum" or Type == "EnumItem"
	end;

	EnumType = function(_, Type) -- For whatever reason, typeof() returns "Enum" for EnumItems
		return Type == "Enum"
	end;

	True = function(Value)
		return Value == true
	end;

	False = function(Value)
		return Value == false
	end;

	Callable = function(Value, Type)
		if Type == "function" then
			return true
		elseif Type == "table" or Type == "userdata" then
			local Metatable = getmetatable(Value)
			if Metatable and type(Metatable.__call) == "function" then
				return true
			end
		end

		return false
	end;
}

local function TransformTableCheckerData(PotentialTypes)
	-- [0] is the Expectation string
	-- Array in the form {"number", "string", "nil"} where each value is a string matchable by typeof()
	-- Key-Value pairs in the form {[string Name] = function}

	if not PotentialTypes[0] then -- It was already transformed if written to 0, no haxing pls
		local Expectation = ": expected "
		PotentialTypes[0] = Expectation

		for Name in next, PotentialTypes do
			local NameType = type(Name)

			if NameType == "string" then
				Expectation ..= Name .. " or "
			elseif NameType ~= "number" then
				FastRequire(Debug).Error("Key-Value pairs should be in the form [string Name] = function, got %s", Name)
			end
		end

		local Index = 0
		local AmountPotentialTypes = #PotentialTypes

		while Index < AmountPotentialTypes do
			Index += 1
			local PotentialType = PotentialTypes[Index]

			if type(PotentialType) ~= "string" then
				FastRequire(Debug).Error("PotentialTypes in the array section must be strings in the form {\"number\", \"string\", \"nil\"}")
			end

			Expectation ..= PotentialType .. " or "
			local TypeCheck = CustomTypes[PotentialType]

			if TypeCheck then
				local Length = #PotentialTypes
				PotentialTypes[Index] = PotentialTypes[Length]
				PotentialTypes[Length] = nil -- table.remove

				Index -= 1
				AmountPotentialTypes -= 1
				PotentialTypes[PotentialType] = TypeCheck
			end
		end

		PotentialTypes[0] = string.sub(Expectation, 1, -5)
	end

	return PotentialTypes
end

local function Check(PotentialTypes, Parameter, ArgumentNumOrName)
	local TypeOf = typeof(Parameter)
	for _, PotentialType in ipairs(PotentialTypes) do
		if PotentialType == TypeOf then
			return Parameter or true
		end
	end

	for Key, CheckFunction in next, PotentialTypes do
		if type(Key) == "string" then
			local Success = CheckFunction(Parameter, TypeOf)

			if Success then
				return string.find(Key, "^Enum") and Success or Parameter or true
			end
		end
	end

	local ArgumentNumberType = type(ArgumentNumOrName)
	return false, "bad argument" .. (ArgumentNumOrName and (ArgumentNumberType == "number" and " #" .. ArgumentNumOrName or ArgumentNumberType == "string" and " to " .. ArgumentNumOrName) or "") .. PotentialTypes[0] .. ", got " .. FastRequire(Debug).Inspect(Parameter)
end

local Typer = {}
local CallToCheck = {__call = Check}

setmetatable(Typer, {
	__index = function(self, Index)
		local Types = {}
		self[Index] = Types

		for ParsedType in string.gmatch(Index .. "Or", "(%w-)Or") do -- Not the prettiest, but hey, we got parsing baby!
			if string.find(ParsedType, "^Optional") then
				ParsedType = string.sub(ParsedType, 9)
				Types[1] = "nil"
			end

			if string.find(ParsedType, "^InstanceOfClass") then
				local ClassName = string.sub(ParsedType, 16)

				Types["Instance of class " .. ClassName] = function(Value, Type)
					return Type == "Instance" and Value.ClassName == ClassName
				end
			elseif string.find(ParsedType, "^InstanceWhichIsAn") then
				local ClassName = string.sub(ParsedType, 18)

				Types["Instance which is an " .. ClassName] = function(Value, Type)
					return Type == "Instance" and Value:IsA(ClassName)
				end
			elseif string.find(ParsedType, "^InstanceWhichIsA") then
				local ClassName = string.sub(ParsedType, 17)

				Types["Instance which is a " .. ClassName] = function(Value, Type)
					return Type == "Instance" and Value:IsA(ClassName)
				end
			elseif string.find(ParsedType, "^EnumOfType") then
				ParsedType = string.sub(ParsedType, 11)
				local Castables = {}
				local EnumValue = Enum[ParsedType]

				for _, Enumerator in ipairs(EnumValue:GetEnumItems()) do
					Castables[Enumerator] = Enumerator
					Castables[Enumerator.Name] = Enumerator
					Castables[Enumerator.Value] = Enumerator
				end

				Types["Enum of type " .. ParsedType] = function(Value)
					return Castables[Value] or false
				end
			elseif string.find(ParsedType, "^EnumerationOfType") then
				ParsedType = string.sub(ParsedType, 18)
				local EnumerationType = FastRequire(Enumeration)[ParsedType]

				Types["Enumeration of type " .. ParsedType] = function(Value)
					return EnumerationType:Cast(Value)
				end
			elseif string.find(ParsedType, "^ArrayOf%a+s$") then
				ParsedType = string.match(ParsedType, "^ArrayOf(%a+)s$")
				local ArrayType = Typer[ParsedType]
				local Function = CustomTypes.Array
				local Castable = string.find(ParsedType, "^Enum") and true or false

				Types["Array of " .. string.gsub(string.sub(ArrayType[0], 12), "%S+", REPLACEMENT, 1)] = function(Value, Type)
					return Function(Value, Type, ArrayType, Castable)
				end
			elseif string.find(ParsedType, "^DictionaryOf%a+s$") then
				ParsedType = string.match(ParsedType, "^DictionaryOf(%a+)s$")
				local DictionaryType = Typer[ParsedType]
				local Function = CustomTypes.Dictionary
				local Castable = string.find(ParsedType, "^Enum") and true or false

				Types["Dictionary of " .. string.gsub(string.sub(DictionaryType[0], 12), "%S+", REPLACEMENT, 1)] = function(Value, Type)
					return Function(Value, Type, DictionaryType, Castable)
				end
			elseif string.find(ParsedType, "^TableOf%a+s$") then
				ParsedType = string.match(ParsedType, "^TableOf(%a+)s$")
				local TableType = Typer[ParsedType]
				local Function = CustomTypes.Table
				local Castable = string.find(ParsedType, "^Enum") and true or false

				Types["Table of " .. string.gsub(string.sub(TableType[0], 12), "%S+", REPLACEMENT, 1)] = function(Value, Type)
					return Function(Value, Type, TableType, Castable)
				end
			else
				table.insert(Types, BuiltInTypes[ParsedType] or ParsedType)
			end
		end

		return setmetatable(TransformTableCheckerData(Types), CallToCheck)
	end;
})

--[[**
	Returns a function which checks to make sure the arguments passed in exactly match the parameters specified. If they match, it will call `Callback`, otherwise it will error, stating which parameter caused the error and what was expected. Each parameter corresponds to the parameter with which the function is being called. Parameters should be arrays containing all valid strings which may be returned by `typeof(parameter)`. For example: `{"string", "number", "nil"}` would allow the corresponding parameter to be a `string`, `number`, or `nil`. Optionally, a table may have a `[string TypeNameKey] = function Callback` which may be called to determine whether a parameter is of the type `TypeNameKey`. The first parameter may optionally be a positive integer which is the first parameter `AssignSignature` should start checking.
	([number ParameterIndexToStartChecking = 1, ] types ... , function Callback)
	@returns [t:function] The same function with type checking abilities.
**--]]
function Typer.AssignSignature(...)
	local FirstValueToCheckOffset = 0
	local StackSignature

	if CustomTypes.PositiveInteger(..., type((...))) then
		FirstValueToCheckOffset = ... - 1
		StackSignature = {select(2, ...)}
	else
		StackSignature = {...}
	end

	local NumTypes = #StackSignature
	local Function = StackSignature[NumTypes]
	local Castable

	StackSignature[NumTypes] = nil
	NumTypes -= 1

	-- local Function = table.remove(StackSignature)

	for Index, ParameterSignature in ipairs(StackSignature) do
		if type(ParameterSignature) == "table" then
			for Key in next, TransformTableCheckerData(ParameterSignature) do
				if type(Key) == "string" and string.find(Key, "^Enum") then
					if not Castable then
						Castable = {}

						for Jndex = 1, Index - 1 do
							Castable[Jndex] = false
						end
					end

					Castable[Index] = true
				end
			end

			if Castable and not Castable[Index] then
				Castable[Index] = false
			end
		else
			FastRequire(Debug).Error("Definition for parameter #" .. Index .. " must be a table")
		end
	end

	if Castable then
		return function(...)
			local Stack = table.pack(...)
			local NumParameters = Stack.n -- This preserves nil's on the stack

			for Index = 1, NumParameters < NumTypes and NumTypes or NumParameters do
				local Success, Error = Check(StackSignature[Index] or Typer.Any, Stack[Index + FirstValueToCheckOffset], Index + FirstValueToCheckOffset)

				if Success then
					if Castable[Index] and Success ~= true then
						Stack[Index + FirstValueToCheckOffset] = Success
					end
				elseif not Success then
					return FastRequire(Debug).Error(Error) -- __call should in theory be faster.
				end
			end

			return Function(table.unpack(Stack, 1, NumParameters))
		end
	else -- Don't penalize cases which don't need to cast an Enum
		return function(...)
			local NumParameters = select("#", ...)

			for Index = 1, NumParameters < NumTypes and NumTypes or NumParameters do
				local Success, Error = Check(StackSignature[Index] or Typer.Any, select(Index + FirstValueToCheckOffset, ...), Index + FirstValueToCheckOffset)

				if not Success then
					return FastRequire(Debug).Error(Error)
				end
			end

			return Function(...)
		end
	end
end

local function PackAssistant(Success, ...)
	return Success, table.pack(...)
end

function Typer.PromiseAssignSignature(...)
	local FirstValueToCheckOffset = 0
	local StackSignature

	if CustomTypes.PositiveInteger(..., type((...))) then
		FirstValueToCheckOffset = ... - 1
		StackSignature = {select(2, ...)}
	else
		StackSignature = {...}
	end

	local NumTypes = #StackSignature
	local Function = StackSignature[NumTypes]
	local Castable

	StackSignature[NumTypes] = nil
	NumTypes -= 1

	for Index, ParameterSignature in ipairs(StackSignature) do
		if type(ParameterSignature) == "table" then
			for Key in next, TransformTableCheckerData(ParameterSignature) do
				if type(Key) == "string" and string.find(Key, "^Enum") then
					if not Castable then
						Castable = {}

						for Jndex = 1, Index - 1 do
							Castable[Jndex] = false
						end
					end

					Castable[Index] = true
				end
			end

			if Castable and not Castable[Index] then
				Castable[Index] = false
			end
		else
			return Promise.Reject("Definition for parameter #" .. Index .. " must be a table")
		end
	end

	if Castable then
		return function(...)
			local NumParameters = select("#", ...) -- This preserves nil's on the stack
			local Stack = {...}

			for Index = 1, NumParameters < NumTypes and NumTypes or NumParameters do
				local Success, Error = Check(StackSignature[Index] or Typer.Any, Stack[Index + FirstValueToCheckOffset], Index + FirstValueToCheckOffset)

				if Success then
					if Castable[Index] and Success ~= true then
						Stack[Index + FirstValueToCheckOffset] = Success
					end
				elseif not Success then
					return Promise.Reject(Error)
				end
			end

			local TypeSuccess, Returned = PackAssistant(Function(table.unpack(Stack, 1, NumParameters)))
			if not TypeSuccess then
				return Promise.Reject(table.unpack(Returned, 1, Returned.n))
			else
				return TypeSuccess, table.unpack(Returned, 1, Returned.n)
			end
		end
	else -- Don't penalize cases which don't need to cast an Enum
		return function(...)
			local NumParameters = select("#", ...)

			for Index = 1, NumParameters < NumTypes and NumTypes or NumParameters do
				local Success, Error = Check(StackSignature[Index] or Typer.Any, select(Index + FirstValueToCheckOffset, ...), Index + FirstValueToCheckOffset)

				if not Success then
					return Promise.Reject(Error)
				end
			end

			local TypeSuccess, Returned = PackAssistant(Function(...))
			if not TypeSuccess then
				return Promise.Reject(table.unpack(Returned, 1, Returned.n))
			else
				return TypeSuccess, table.unpack(Returned, 1, Returned.n)
			end
		end
	end
end

local ExternalTransformTable = Typer.AssignSignature(Typer.Table, TransformTableCheckerData)
function Typer.Check(PotentialTypes, Parameter, ArgumentNumOrName)
	return Check(ExternalTransformTable(PotentialTypes), Parameter, ArgumentNumOrName)
end

Typer.MapStrictDefinition = Typer.AssignSignature(Typer.Table, function(self)
	for _, Type in next, self do
		ExternalTransformTable(Type)
	end

	return function(Tab)
		if type(Tab) ~= "table" then
			return false, "|Map.__call| Must be called with a Table"
		end

		for Index in next, Tab do
			if not self[Index] then
				return false, "|Map.__call| " .. FastRequire(Debug).Inspect(Index) .. " is not a valid Key"
			end
		end

		for Index, Type in next, self do
			local Success, Error = Typer.Check(Type, Tab[Index], Index)

			if not Success then
				return false, "|Map.__call| " .. Error
			end
		end

		return Tab
	end
end)

Typer.MapDefinition = Typer.AssignSignature(Typer.Table, function(self)
	for _, Type in next, self do
		ExternalTransformTable(Type)
	end

	return function(Tab)
		if type(Tab) ~= "table" then
			return false, "|Map.__call| Must be called with a Table"
		end

		for Index, Type in next, self do
			local Success, Error = Typer.Check(Type, Tab[Index], Index)

			if not Success then
				return false, "|Map.__call| " .. Error
			end
		end

		return Tab
	end
end)

return Typer
