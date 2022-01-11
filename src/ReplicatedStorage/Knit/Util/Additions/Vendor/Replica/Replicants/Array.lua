local Option = require(script.Parent.Parent.Parent.Parent.Parent.Option)
local Replicant = require(script.Parent.Parent.Replicant)

local Array, Members = Replicant.Extend()
local Metatable = {__index = Members}

function Members:IndexOf(Needle)
	for Index, Value in ipairs(self.Wrapped) do
		if Needle == Value then
			return Index
		end
	end

	return nil
end

function Members:IndexOfOption(Needle)
	for Index, Value in ipairs(self.Wrapped) do
		if Needle == Value then
			return Option.Some(Index)
		end
	end

	return Option.None
end

function Members:Iterate()
	return ipairs(self.Wrapped)
end

function Members:Iterator()
	return ipairs(self.Wrapped)
end

function Members:Ipairs()
	return ipairs(self.Wrapped)
end

function Members:Size()
	return #self.Wrapped
end

function Members:GetSize()
	return #self.Wrapped
end

function Members:GetLength()
	return #self.Wrapped
end

function Members:Insert(...)
	if select("#", ...) == 2 then
		local Index, Value = ...
		if type(Index) ~= "number" then
			error("Bad argument #1 to Insert (number expected, got " .. typeof(Index) .. ")")
		end

		local Wrapped = self.Wrapped
		local function ShiftAndInsert()
			local InsertIndex = #Wrapped + 1
			for NewIndex = #Wrapped, Index, -1 do
				self:Set(NewIndex + 1, Wrapped[NewIndex])
				InsertIndex = NewIndex
			end

			self:Set(InsertIndex, Value)
		end

		if self:_InCollatingContext() then
			ShiftAndInsert()
		else
			self:Collate(ShiftAndInsert)
		end
	else
		self:Set(#self.Wrapped + 1, (...))
	end
end

function Members:Remove(RemoveIndex)
	local function Shift()
		local Wrapped = self.Wrapped
		for Index = RemoveIndex, #Wrapped do
			self:Set(Index, Wrapped[Index + 1])
		end
	end

	if self:_InCollatingContext() then
		Shift()
	else
		self:Collate(Shift)
	end
end

function Members:Push(Value)
	self:Set(#self.Wrapped + 1, Value)
end

function Members:Pop()
	self:Set(#self.Wrapped, nil)
end

function Members:_SetLocal(Index, Value)
	if type(Index) ~= "number" or Index > #self.Wrapped + 1 or Index % 1 ~= 0 then
		error("Array Replicant keys must be sequential integers")
	end

	self.Wrapped[Index] = Value
end

Array.SerialType = "ArrayReplicant"
function Array:Constructor(InitialValues, ...)
	Replicant.Constructor(self, ...)
	if InitialValues ~= nil then
		local ExpectedIndex = 1
		for Index, Value in ipairs(InitialValues) do
			if Index ~= ExpectedIndex then
				error("Array Replicant keys must be sequential integers")
			end

			ExpectedIndex += 1
			self:_SetLocal(Index, Value)
		end
	end
end

function Array.new(...)
	local self = setmetatable({}, Metatable)
	Array.Constructor(self, ...)
	return self
end

function Array:__tostring()
	return "Array"
end

return Array
