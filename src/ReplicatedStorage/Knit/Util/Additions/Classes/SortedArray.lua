--- @typecheck mode: nocheck
local SortedArray = {}
SortedArray.ClassName = "SortedArray"
SortedArray.__index = {}

SortedArray.__index.Concat = table.concat
SortedArray.__index.RemoveIndex = table.remove --Table.FastRemove;
SortedArray.__index.Unpack = table.unpack

local Comparisons = setmetatable({}, {__mode = "k"})

type CompareFunction<T> = (ValueA: T, ValueB: T) -> boolean

function SortedArray.new<T>(This: {T}?, Comparison: CompareFunction<T>?)
	local self

	if This then
		table.sort(This, Comparison)
		self = This
	else
		self = {}
	end

	Comparisons[self] = Comparison
	return setmetatable(self, SortedArray)
end

local function FindClosest(self, Value, Low, High, Eq, Lt)
	local Middle

	do
		local Sum = Low + High
		Middle = (Sum - Sum % 2) / 2
	end

	if Middle == 0 then
		return nil
	end

	local Compare = Lt or Comparisons[self]
	local Value2 = self[Middle]

	while Middle ~= High do
		if Eq then
			if Eq(Value, Value2) then
				return Middle
			end
		elseif Value == Value2 then
			return Middle
		end

		local Bool = if Compare then Compare(Value, Value2) else Value < Value2
		if Bool then
			High = Middle - 1
		else
			Low = Middle + 1
		end

		local Sum = Low + High
		Middle = (Sum - Sum % 2) / 2
		Value2 = self[Middle]
	end

	return Middle
end

function SortedArray.__index:ForEach(Predicate)
	for Index, Value in ipairs(self) do
		Predicate(Value, Index, self)
	end
end

function SortedArray.__index:Map(Predicate)
	local Result = {}
	for Index, Value in ipairs(self) do
		Result[Index] = Predicate(Value, Index, self)
	end

	return Result
end

function SortedArray.__index:Some(Predicate)
	for Index, Value in ipairs(self) do
		if Predicate(Value, Index, self) == true then
			return true
		end
	end

	return false
end

function SortedArray.__index:Every(Predicate)
	for Index, Value in ipairs(self) do
		if not Predicate(Value, Index, self) then
			return false
		end
	end

	return true
end

function SortedArray.__index:Reduce(Predicate, InitialValue)
	local First = 1
	local Last = #self
	local Accumulator

	if InitialValue == nil then
		if Last == 0 then
			error("Reduce of empty array with no initial value at SortedArray:Reduce", 2)
		end

		Accumulator = self[First]
		First += 1
	else
		Accumulator = InitialValue
	end

	for Index = First, Last do
		Accumulator = Predicate(Accumulator, self[Index], Index, self)
	end

	return Accumulator
end

function SortedArray.__index:ReduceRight(Predicate, InitialValue)
	local First = #self
	local Last = 1
	local Accumulator

	if InitialValue == nil then
		if First == 0 then
			error("Reduce of empty array with no initial value at SortedArray:ReduceRight", 2)
		end

		Accumulator = self[First]
		First -= 1
	else
		Accumulator = InitialValue
	end

	for Index = First, Last, -1 do
		Accumulator = Predicate(Accumulator, self[Index], Index, self)
	end

	return Accumulator
end

local function Filter(self, Predicate)
	local NewSelf = {}
	local Length = 0

	for Index, Value in ipairs(self) do
		if Predicate(Value, Index, self) == true then
			Length += 1
			NewSelf[Length] = Value
		end
	end

	return NewSelf
end

function SortedArray.__index:Filter(Predicate)
	local NewSelf = setmetatable(Filter(self, Predicate), SortedArray)
	Comparisons[NewSelf] = Comparisons[self]
	return NewSelf
end

-- Fast!!!!!!
local function Slice(self, StartIndex, EndIndex)
	local Length = #self
	StartIndex = if StartIndex == nil then 0 else StartIndex
	EndIndex = if EndIndex == nil then Length else EndIndex

	if StartIndex < 0 then
		StartIndex += Length
	end

	if EndIndex < 0 then
		EndIndex += Length
	end

	return table.move(self, StartIndex + 1, EndIndex, 1, table.create(if StartIndex > EndIndex then StartIndex - EndIndex else EndIndex - StartIndex))
end

function SortedArray.__index:Slice(StartIndex, EndIndex)
	local NewSelf = setmetatable(Slice(self, StartIndex, EndIndex), SortedArray)
	Comparisons[NewSelf] = Comparisons[self]
	return NewSelf
end

local function MapFilter(self, Predicate)
	local NewSelf = {}
	local Length = 0

	for Index, Value in ipairs(self) do
		local Result = Predicate(Value, Index, self)
		if Result ~= nil then
			Length += 1
			NewSelf[Length] = Result
		end
	end

	return NewSelf
end

function SortedArray.__index:MapFilter(Predicate)
	local NewSelf = setmetatable(MapFilter(self, Predicate), SortedArray)
	Comparisons[NewSelf] = Comparisons[self]
	return NewSelf
end

function SortedArray.__index:Insert(Value)
	-- Inserts a Value into the SortedArray while maintaining its sortedness
	local Position = FindClosest(self, Value, 1, #self)
	local Value2 = self[Position]

	if Value2 then
		local Compare = Comparisons[self]
		local Bool = if Compare then Compare(Value, Value2) else Value < Value2
		Position = Bool and Position or Position + 1
	else
		Position = 1
	end

	table.insert(self, Position, Value)
	return Position
end

function SortedArray.__index:Find(Value, Eq, Lt, U_0, U_n)
	-- Finds a Value in a SortedArray and returns its position (or nil if non-existant)
	local Position = FindClosest(self, Value, U_0 or 1, U_n or #self, Eq, Lt)
	local Bool = if Position then if Eq then Eq(Value, self[Position]) else Value == self[Position] else nil

	--if Position then
	--	Bool = if Eq then Eq(Value, self[Position]) else Value == self[Position]
	--end

	return Bool and Position or nil
end

SortedArray.__index.IndexOf = SortedArray.__index.Find

function SortedArray.__index:Copy()
	local Length = #self
	return table.move(self, 1, Length, 1, table.create(Length))
end

function SortedArray.__index:Clone()
	local Length = #self
	local New = table.move(self, 1, Length, 1, table.create(Length))
	Comparisons[New] = Comparisons[self]
	return setmetatable(New, SortedArray)
end

function SortedArray.__index:RemoveElement(Signature, Eq, Lt)
	local Position = self:Find(Signature, Eq, Lt)

	if Position then
		return self:RemoveIndex(Position)
	end
end

function SortedArray.__index:Sort()
	table.sort(self, Comparisons[self])
end

function SortedArray.__index:SortIndex(Index)
	-- Sorts a single element at number Index
	-- Useful for when a single element is somehow altered such that it should get a new position in the array

	return self:Insert(self:RemoveIndex(Index))
end

function SortedArray.__index:SortElement(Signature, Eq, Lt)
	-- Sorts a single element if it exists
	-- Useful for when a single element is somehow altered such that it should get a new position in the array

	return self:Insert(self:RemoveElement(Signature, Eq, Lt))
end

function SortedArray.__index:GetIntersection(SortedArray2, Eq, Lt)
	-- Returns a SortedArray of Commonalities between self and another SortedArray
	-- If applicable, the returned SortedArray will inherit the Comparison function from self
	if SortedArray ~= getmetatable(SortedArray2) then
		error("bad argument #2 to GetIntersection: expected SortedArray, got " .. typeof(SortedArray2) .. " " .. tostring(SortedArray2))
	end

	local Commonalities = SortedArray.new(nil, Comparisons[self])
	local Count = 0
	local Position = 1
	local NumSelf = #self
	local NumSortedArray2 = #SortedArray2

	if NumSelf > NumSortedArray2 then -- Iterate through the shorter SortedArray
		NumSelf, NumSortedArray2 = NumSortedArray2, NumSelf
		self, SortedArray2 = SortedArray2, self
	end

	for Index = 1, NumSelf do
		local Current = self[Index]
		local CurrentPosition = SortedArray2:Find(Current, Eq, Lt, Position, NumSortedArray2)

		if CurrentPosition then
			Position = CurrentPosition
			Count += 1
			Commonalities[Count] = Current
		end
	end

	return Commonalities
end

local function GetMedian(self, A, B)
	local C = A + B

	if C % 2 == 0 then
		return self[C / 2]
	else
		local D = (C - 1) / 2
		return (self[D] + self[D + 1]) / 2
	end
end

function SortedArray.__index:Front()
	return self[1]
end

function SortedArray.__index:Back()
	return self[#self]
end

function SortedArray.__index:Median()
	return GetMedian(self, 1, #self)
end

function SortedArray.__index:Quartile1()
	local Length = #self
	return GetMedian(self, 1, (Length - Length % 2) / 2)
end

function SortedArray.__index:Quartile3()
	local Length = #self
	return GetMedian(self, 1 + (Length + Length % 2) / 2, Length)
end

function SortedArray:__tostring()
	local Length = #self
	local String = table.move(self, 1, Length, 1, table.create(Length))
	for Index, Value in ipairs(String) do
		String[Index] = tostring(Value)
	end

	return string.format("SortedArray<[%s]>", table.concat(String, ", "))
end

export type SortedArray<T> = typeof(SortedArray.new({1, 2, 3}))
table.freeze(SortedArray)
return SortedArray
