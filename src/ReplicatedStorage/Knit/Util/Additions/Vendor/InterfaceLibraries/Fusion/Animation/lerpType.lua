--!strict

--[[
	Linearly interpolates the given animatable types by a ratio.
	If the types are different or not animatable, then the first value will be
	returned for ratios below 0.5, and the second value for 0.5 and above.

	FIXME: This function uses a lot of redefinitions to suppress false positives
	from the Luau typechecker - ideally these wouldn't be required
]]

local Oklab = require(script.Parent.Parent.Colour.Oklab)

local function lerpType(from: any, to: any, ratio: number): any
	local typeString = typeof(from)

	if typeof(to) == typeString then
		-- both types must match for interpolation to make sense
		if typeString == "number" then
			local localTo, localFrom = to :: number, from :: number
			return (localTo - localFrom) * ratio + localFrom
		elseif typeString == "CFrame" then
			local localTo, localFrom = to :: CFrame, from :: CFrame
			return localFrom:Lerp(localTo, ratio)
		elseif typeString == "Color3" then
			local localTo, localFrom = to :: Color3, from :: Color3
			local fromLab = Oklab.to(localFrom)
			local toLab = Oklab.to(localTo)
			return Oklab.from(fromLab:Lerp(toLab, ratio), false)
		elseif typeString == "ColorSequenceKeypoint" then
			local localTo, localFrom = to :: ColorSequenceKeypoint, from :: ColorSequenceKeypoint
			local fromLab = Oklab.to(localFrom.Value)
			local toLab = Oklab.to(localTo.Value)
			return ColorSequenceKeypoint.new((localTo.Time - localFrom.Time) * ratio + localFrom.Time, Oklab.from(fromLab:Lerp(toLab, ratio), false))
		elseif typeString == "DateTime" then
			local localTo, localFrom = to :: DateTime, from :: DateTime
			return DateTime.fromUnixTimestampMillis((localTo.UnixTimestampMillis - localFrom.UnixTimestampMillis) * ratio + localFrom.UnixTimestampMillis)
		elseif typeString == "NumberRange" then
			local localTo, localFrom = to :: NumberRange, from :: NumberRange
			return NumberRange.new((localTo.Min - localFrom.Min) * ratio + localFrom.Min, (localTo.Max - localFrom.Max) * ratio + localFrom.Max)
		elseif typeString == "NumberSequenceKeypoint" then
			local localTo, localFrom = to :: NumberSequenceKeypoint, from :: NumberSequenceKeypoint
			return NumberSequenceKeypoint.new((localTo.Time - localFrom.Time) * ratio + localFrom.Time, (localTo.Value - localFrom.Value) * ratio + localFrom.Value, (localTo.Envelope - localFrom.Envelope) * ratio + localFrom.Envelope)
		elseif typeString == "PhysicalProperties" then
			local localTo, localFrom = to :: PhysicalProperties, from :: PhysicalProperties
			return PhysicalProperties.new((localTo.Density - localFrom.Density) * ratio + localFrom.Density, (localTo.Friction - localFrom.Friction) * ratio + localFrom.Friction, (localTo.Elasticity - localFrom.Elasticity) * ratio + localFrom.Elasticity, (localTo.FrictionWeight - localFrom.FrictionWeight) * ratio + localFrom.FrictionWeight, (localTo.ElasticityWeight - localFrom.ElasticityWeight) * ratio + localFrom.ElasticityWeight)
		elseif typeString == "Ray" then
			local localTo, localFrom = to :: Ray, from :: Ray
			return Ray.new(localFrom.Origin:Lerp(localTo.Origin, ratio), localFrom.Direction:Lerp(localTo.Direction, ratio))
		elseif typeString == "Rect" then
			local localTo, localFrom = to :: Rect, from :: Rect
			return Rect.new(localFrom.Min:Lerp(localTo.Min, ratio), localFrom.Max:Lerp(localTo.Max, ratio))
		elseif typeString == "Region3" then
			local localTo, localFrom = to :: Region3, from :: Region3
			-- FUTURE: support rotated Region3s if/when they become constructable
			local position = localFrom.CFrame.Position:Lerp(localTo.CFrame.Position, ratio)
			local halfSize = localFrom.Size:Lerp(localTo.Size, ratio) / 2
			return Region3.new(position - halfSize, position + halfSize)
		elseif typeString == "Region3int16" then
			local localTo, localFrom = to :: Region3int16, from :: Region3int16
			return Region3int16.new(Vector3int16.new((localTo.Min.X - localFrom.Min.X) * ratio + localFrom.Min.X, (localTo.Min.Y - localFrom.Min.Y) * ratio + localFrom.Min.Y, (localTo.Min.Z - localFrom.Min.Z) * ratio + localFrom.Min.Z), Vector3int16.new((localTo.Max.X - localFrom.Max.X) * ratio + localFrom.Max.X, (localTo.Max.Y - localFrom.Max.Y) * ratio + localFrom.Max.Y, (localTo.Max.Z - localFrom.Max.Z) * ratio + localFrom.Max.Z))
		elseif typeString == "UDim" then
			local localTo, localFrom = to :: UDim, from :: UDim
			return UDim.new((localTo.Scale - localFrom.Scale) * ratio + localFrom.Scale, (localTo.Offset - localFrom.Offset) * ratio + localFrom.Offset)
		elseif typeString == "UDim2" then
			local localTo, localFrom = to :: UDim2, from :: UDim2
			return localFrom:Lerp(localTo, ratio)
		elseif typeString == "Vector2" then
			local localTo, localFrom = to :: Vector2, from :: Vector2
			return localFrom:Lerp(localTo, ratio)
		elseif typeString == "Vector2int16" then
			local localTo, localFrom = to :: Vector2int16, from :: Vector2int16
			return Vector2int16.new((localTo.X - localFrom.X) * ratio + localFrom.X, (localTo.Y - localFrom.Y) * ratio + localFrom.Y)
		elseif typeString == "Vector3" then
			local localTo, localFrom = to :: Vector3, from :: Vector3
			return localFrom:Lerp(localTo, ratio)
		elseif typeString == "Vector3int16" then
			local localTo, localFrom = to :: Vector3int16, from :: Vector3int16
			return Vector3int16.new((localTo.X - localFrom.X) * ratio + localFrom.X, (localTo.Y - localFrom.Y) * ratio + localFrom.Y, (localTo.Z - localFrom.Z) * ratio + localFrom.Z)
		end
	end

	-- fallback case: the types are different or not animatable
	if ratio < 0.5 then
		return from
	else
		return to
	end
end

return lerpType
