local StringRep = require(script.Parent.Parent.Parent.Utility.StringRep)

local Utility = {}

function Utility.Copy(Table)
	local NewTable = {}
	for Index, Value in next, Table do
		NewTable[Index] = Value
	end

	return NewTable
end

local function DeepCopy(Table)
	local NewTable = {}
	for Index, Value in next, Table do
		if type(Value) == "table" then
			NewTable[Index] = DeepCopy(Value)
		else
			NewTable[Index] = Value
		end
	end

	return NewTable
end

local function DeepCompare(Value1, Value2)
	if type(Value1) == "table" and type(Value2) == "table" then
		for Index, Value in next, Value1 do
			if not DeepCompare(Value, Value2[Index]) then
				return false
			end
		end

		return true
	else
		return Value1 == Value2
	end
end

local function OverrideDefaults(Defaults, Table)
	local NewTable = DeepCopy(Defaults)

	for Index, Value in next, Table do
		local Existing = Defaults[Index]
		if Existing and type(Value) == "table" and type(Existing) == "table" then
			NewTable[Index] = OverrideDefaults(Existing, Value)
		else
			NewTable[Index] = Value
		end
	end

	return NewTable
end

Utility.DeepCopy = DeepCopy
Utility.DeepCompare = DeepCompare
Utility.OverrideDefaults = OverrideDefaults

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
-- Most standard roblox data types are supported, so long as they are reversible
-- i.e. parameters in the constructor can be inferred from the object's public properties

local function Serialize(Key, Object)
	local SerializedType
	local SymbolicValue

	local TypeOf = typeof(Object)
	if TypeOf == "number" or TypeOf == "string" or TypeOf == "boolean" or TypeOf == "nil" or TypeOf == "EnumItem" then
		SerializedType = "Raw"
		SymbolicValue = Object
	elseif TypeOf == "table" then
		SerializedType = "Table"
		SymbolicValue = {}
		if #Object == 0 then
			for Index, Value in next, Object do
				if type(Index) ~= "string" then
					error("Serialized nonsequential tables must have string keys (encountered non-string key '" .. Key .. "[" .. tostring(Index) .. "]' when calling Util.Serialize)")
				end

				SymbolicValue[Index] = Serialize(Index, Value)
			end
		else
			local ExpectedIndex = 1
			for Index, Value in ipairs(Object) do
				if Index ~= ExpectedIndex then
					error("Serialized array tables must have sequential keys (encountered non-sequential key '" .. Key .. "[" .. tostring(Index) .. "]' when calling Util.Serialize)")
				end

				ExpectedIndex += 1
				SymbolicValue[Index] = Serialize(Index, Value)
			end
		end
	elseif TypeOf == "Axes" then
		SerializedType = TypeOf
		SymbolicValue = {Object.X, Object.Y, Object.Z, Object.Top, Object.Bottom, Object.Left, Object.Right, Object.Back, Object.Front}
	elseif TypeOf == "BrickColor" then
		SerializedType = TypeOf
		SymbolicValue = Object.Number
	elseif TypeOf == "CFrame" then
		SerializedType = TypeOf
		SymbolicValue = {Object:GetComponents()}
	elseif TypeOf == "Color3" then
		SerializedType = TypeOf
		SymbolicValue = {Object.R, Object.G, Object.B}
	elseif TypeOf == "ColorSequence" or TypeOf == "NumberSequence" then
		SerializedType = TypeOf
		SymbolicValue = {}
		for Index, Keypoint in ipairs(Object.Keypoints) do
			SymbolicValue[Index] = Serialize(Index, Keypoint)
		end
	elseif TypeOf == "ColorSequenceKeypoint" then
		SerializedType = TypeOf
		SymbolicValue = {Serialize(1, Object.Time), Serialize(2, Object.Value)}
	elseif TypeOf == "Faces" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Top, Object.Bottom, Object.Left, Object.Right, Object.Back, Object.Front}
	elseif TypeOf == "NumberRange" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Min, Object.Max}
	elseif TypeOf == "NumberSequenceKeypoint" then
		SerializedType = TypeOf
		SymbolicValue = {Serialize(1, Object.Time), Serialize(2, Object.Value), Serialize(3, Object.Envelope)}
	elseif TypeOf == "PathWaypoint" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Position, Object.Action}
	elseif TypeOf == "PhysicalProperties" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Density, Object.Friction, Object.Elasticity, Object.FrictionWeight, Object.ElasticityWeight}
	elseif TypeOf == "Ray" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Origin, Object.Direction}
	elseif TypeOf == "Rect" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Min.X, Object.Min.Y, Object.Max.X, Object.Max.Y}
	elseif TypeOf == "Region3" then
		SerializedType = TypeOf
		SymbolicValue = {Serialize(1, Object.CFrame.Position - Object.Size / 2), Serialize(2, Object.CFrame.Position + Object.Size / 2)}
	elseif TypeOf == "TweenInfo" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Time, Object.EasingDirection, Object.EasingStyle, Object.EasingDirection, Object.RepeatCount, Object.Reverses, Object.DelayTime}
	elseif TypeOf == "UDim" then
		SerializedType = TypeOf
		SymbolicValue = {Object.Scale, Object.Offset}
	elseif TypeOf == "UDim2" then
		SerializedType = TypeOf
		SymbolicValue = {Object.X.Scale, Object.X.Offset, Object.Y.Scale, Object.Y.Offset}
	elseif TypeOf == "Vector2" or TypeOf == "Vector2int16" then
		SerializedType = TypeOf
		SymbolicValue = {Object.X, Object.Y}
	elseif TypeOf == "Vector3" or TypeOf == "Vector3int16" then
		SerializedType = TypeOf
		SymbolicValue = {Object.X, Object.Y, Object.Z}
	else
		error("Type '" .. TypeOf .. "' is not supported (encountered at key '" .. Key .. "' when calling Util.Serialize)")
	end

	return {Key, SerializedType, SymbolicValue}
end

Utility.Serialize = Serialize

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
local function Deserialize(Serialized)
	local SerializedType = Serialized[2]
	local SymbolicValue = Serialized[3]

	if SerializedType == "Raw" then
		return SymbolicValue
	elseif SerializedType == "Table" then
		local Table = {}
		for _, SerializedValue in ipairs(SymbolicValue) do
			Table[SerializedValue[1]] = Deserialize(SerializedValue)
		end

		return Table
	elseif SerializedType == "Axes" then
		local AxisList = {}
		local Index = 1
		local function CheckAxis(Name)
			if SymbolicValue[Index] then
				table.insert(AxisList, Name)
			end

			Index += 1
		end

		CheckAxis(Enum.Axis.X)
		CheckAxis(Enum.Axis.Y)
		CheckAxis(Enum.Axis.Z)
		CheckAxis(Enum.NormalId.Top)
		CheckAxis(Enum.NormalId.Bottom)
		CheckAxis(Enum.NormalId.Left)
		CheckAxis(Enum.NormalId.Right)
		CheckAxis(Enum.NormalId.Back)
		CheckAxis(Enum.NormalId.Front)

		return Axes.new(table.unpack(AxisList))
	elseif SerializedType == "BrickColor" then
		return BrickColor.new(SymbolicValue)
	elseif SerializedType == "CFrame" then
		return CFrame.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Color3" then
		return Color3.new(table.unpack(SymbolicValue))
	elseif SerializedType == "ColorSequence" then
		local Keypoints = {}
		for _, SerializedKeypoint in ipairs(SymbolicValue) do
			Keypoints[SerializedKeypoint[2]] = Deserialize(SerializedKeypoint)
		end

		return ColorSequence.new(Keypoints)
	elseif SerializedType == "ColorSequenceKeypoint" then
		local Arguments = {}
		for _, SerializedArgument in ipairs(SymbolicValue) do
			Arguments[SerializedArgument[2]] = Deserialize(SerializedArgument)
		end

		return ColorSequenceKeypoint.new(table.unpack(Arguments))
	elseif SerializedType == "Faces" then
		local FaceList = {}
		local Index = 1
		local function CheckFace(Name)
			if SymbolicValue[Index] then
				table.insert(FaceList, Name)
			end

			Index += 1
		end

		CheckFace(Enum.NormalId.Top)
		CheckFace(Enum.NormalId.Bottom)
		CheckFace(Enum.NormalId.Left)
		CheckFace(Enum.NormalId.Right)
		CheckFace(Enum.NormalId.Back)
		CheckFace(Enum.NormalId.Front)

		return Faces.new(table.unpack(FaceList))
	elseif SerializedType == "NumberRange" then
		return NumberRange.new(table.unpack(SymbolicValue))
	elseif SerializedType == "NumberSequence" then
		local Keypoints = {}
		for _, SerializedKeypoint in ipairs(SymbolicValue) do
			Keypoints[SerializedKeypoint[2]] = Deserialize(SerializedKeypoint)
		end

		return NumberSequence.new(Keypoints)
	elseif SerializedType == "NumberSequenceKeypoint" then
		local Arguments = {}
		for _, SerializedArgument in ipairs(SymbolicValue) do
			Arguments[SerializedArgument[2]] = Deserialize(SerializedArgument)
		end

		return NumberSequenceKeypoint.new(table.unpack(Arguments))
	elseif SerializedType == "PathWaypoint" then
		return PathWaypoint.new(table.unpack(SymbolicValue))
	elseif SerializedType == "PhysicalProperties" then
		return PhysicalProperties.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Ray" then
		return Ray.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Rect" then
		return Rect.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Region3" then
		local Arguments = {}
		for _, SerializedArgument in ipairs(SymbolicValue) do
			Arguments[SerializedArgument[2]] = Deserialize(SerializedArgument)
		end

		return Region3.new(table.unpack(Arguments))
	elseif SerializedType == "TweenInfo" then
		return TweenInfo.new(table.unpack(SymbolicValue))
	elseif SerializedType == "UDim" then
		return UDim.new(table.unpack(SymbolicValue))
	elseif SerializedType == "UDim2" then
		return UDim2.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Vector2" then
		return Vector2.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Vector2int16" then
		return Vector2int16.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Vector3" then
		return Vector3.new(table.unpack(SymbolicValue))
	elseif SerializedType == "Vector3int16" then
		return Vector3int16.new(table.unpack(SymbolicValue))
	end

	return nil
end

Utility.Deserialize = Deserialize

local NextId = 0
function Utility.NextId()
	NextId += 1
	return NextId
end

local function Inspect(Table, MaxDepth, CurrentDepth, Key)
	MaxDepth = MaxDepth or math.huge
	CurrentDepth = CurrentDepth or 0
	if CurrentDepth > MaxDepth then
		return
	end

	local CurrentIndent = StringRep("	", CurrentDepth)
	local NextIndent = StringRep("	", CurrentDepth + 1)
	print(CurrentIndent .. (Key and (Key .. " = ") or "") .. tostring(Table) .. " {")

	for Index, Value in next, Table do
		if type(Value) == "table" then
			Inspect(Value, MaxDepth, CurrentDepth + 1)
		else
			local IndexString = tostring(Index)
			if type(Index) == "number" then
				IndexString = "[" .. IndexString .. "]"
			end

			local ValueString
			if type(Value) == "string" then
				ValueString = "'" .. tostring(Value) .. "'"
			else
				ValueString = tostring(Value)
			end

			print(NextIndent .. tostring(IndexString), "=", ValueString .. ",")
		end
	end

	print(CurrentIndent .. "}")
end

Utility.Inspect = Inspect
table.freeze(Utility)
return Utility
