local Debug = require(script.Parent.Parent.Debugging.Debug)
local SortedArray = require(script.Parent.Parent.Classes.SortedArray)
local Typer = require(script.Parent.Parent.Debugging.Typer)

local ErrorIndex = {}
function ErrorIndex:__index(Index)
	Debug.Error(tostring(Index) .. " is not a valid EnumerationItem")
end

local ErrorIndex2 = {}
function ErrorIndex2:__index(Index)
	Debug.Error(tostring(Index) .. " is not a valid member")
end

local EnumerationsArray = SortedArray.new(nil, function(Left, Right)
	return tostring(Left) < tostring(Right)
end)

local Enumerations = setmetatable({}, ErrorIndex)
function Enumerations:GetEnumerations()
	return EnumerationsArray:Copy()
end

local function ReadOnlyNewIndex(_, Index)
	Debug.Error("Cannot write to index [%q]", Index)
end

local function CompareEnumTypes(EnumItem1, EnumItem2)
	return EnumItem1.Value < EnumItem2.Value
end

local Casts = {}
local EnumContainerTemplate = {}
EnumContainerTemplate.__index = setmetatable({}, ErrorIndex)

function EnumContainerTemplate.__index:GetEnumerationItems()
	local Array = {}
	local Length = 0

	for _, Item in next, EnumContainerTemplate[self] do
		Length += 1
		Array[Length] = Item
	end

	table.sort(Array, CompareEnumTypes)
	return Array
end

function EnumContainerTemplate.__index:Cast(Value)
	local Castables = Casts[self]
	local Cast = Castables[Value]

	if Cast then
		return Cast
	else
		return false, "[" .. Debug.Inspect(Value) .. "] is not a valid " .. tostring(self)
	end
end

local function ConstructUserdata(__index, __newindex, __tostring)
	local Enumeration = newproxy(true)

	local EnumerationMetatable = getmetatable(Enumeration)
	EnumerationMetatable.__index = __index
	EnumerationMetatable.__metatable = "[Enumeration] Requested metatable is locked"
	EnumerationMetatable.__newindex = __newindex
	function EnumerationMetatable:__tostring()
		return __tostring
	end

	return Enumeration
end

local function ConstructEnumerationItem(Name, Value, EnumContainer, LockedEnumContainer, EnumerationStringStub, Castables)
	local Item = ConstructUserdata(setmetatable({
		EnumerationType = LockedEnumContainer;
		Name = Name;
		Value = Value;
	}, ErrorIndex2), ReadOnlyNewIndex, EnumerationStringStub .. Name)

	Castables[Name] = Item
	Castables[Value] = Item
	Castables[Item] = Item

	EnumContainer[Name] = Item
end

local MakeEnumeration = Typer.AssignSignature(2, Typer.String, Typer.ArrayOfStringsOrDictionaryOfNumbers, function(_, EnumType, EnumTypes)
	if rawget(Enumerations, EnumType) then
		Debug.Error("Enumeration of EnumType " .. EnumType .. " already exists")
	end

	local Castables = {}
	local EnumContainer = setmetatable({}, EnumContainerTemplate)
	local LockedEnumContainer = ConstructUserdata(EnumContainer, ReadOnlyNewIndex, EnumType)
	local EnumerationStringStub = "Enumeration." .. EnumType .. "."

	if #EnumTypes > 0 then
		for Index, Value in ipairs(EnumTypes) do
			ConstructEnumerationItem(Value, Index - 1, EnumContainer, LockedEnumContainer, EnumerationStringStub, Castables)
		end
	else
		for Name, Value in next, EnumTypes do
			ConstructEnumerationItem(Name, Value, EnumContainer, LockedEnumContainer, EnumerationStringStub, Castables)
		end
	end

	Casts[LockedEnumContainer] = Castables
	EnumContainerTemplate[LockedEnumContainer] = EnumContainer
	EnumerationsArray:Insert(LockedEnumContainer)
	Enumerations[EnumType] = LockedEnumContainer
end)

return ConstructUserdata(Enumerations, MakeEnumeration, "Enumerations")
