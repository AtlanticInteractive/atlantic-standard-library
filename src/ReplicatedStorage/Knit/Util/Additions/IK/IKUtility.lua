--[=[
	Utilities for IK system
	@class IKUtility
]=]

local IKUtility = {}

function IKUtility.GetDampenedAngleClamp(MaxAngle, DampenAreaAngle, DampenAreaFactor)
	DampenAreaFactor = DampenAreaFactor or DampenAreaAngle
	return function(Angle)
		local Minimum = MaxAngle - DampenAreaAngle
		if math.abs(Angle) <= Minimum then
			return Angle
		else
			-- dampenAreaFactor is the area that the bouncing happens
			-- dampenAreaAngle is the amount of bounce that occurs
			local TimesOver = (math.abs(Angle) - Minimum) / DampenAreaFactor
			local Scale = 1 - 0.5 ^ TimesOver

			return math.sign(Angle) * (Minimum + Scale * DampenAreaAngle)
		end
	end
end

table.freeze(IKUtility)
return IKUtility
