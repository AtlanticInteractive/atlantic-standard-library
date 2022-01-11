local VELOCITY_THRESHOLD = 0.001
local POSITION_THRESHOLD = 0.001

local EPS = 0.0001

local Spring = {}
Spring.ClassName = "Spring"
Spring.__index = Spring

export type Options = {
	DampingRatio: number?,
	Frequency: number?,
}

function Spring.new(TargetValue, PossibleOptions: Options?)
	assert(TargetValue, "Missing argument #1: targetValue")
	local Options = PossibleOptions or {}

	return setmetatable({
		_DampingRatio = Options.DampingRatio or 1;
		_Frequency = Options.Frequency or 4;
		_TargetValue = TargetValue;
	}, Spring)
end

function Spring:Step(State, DeltaTime)
	-- Copyright 2018 Parker Stebbins (parker@fractality.io)
	-- github.com/Fraktality/Spring
	-- Distributed under the MIT license

	local d = self._DampingRatio
	local f = self._Frequency * 6.2831853071796
	local g = self._TargetValue
	local p0 = State.value
	local v0 = State.velocity or 0

	local offset = p0 - g
	local decay = math.exp(-d * f * DeltaTime)

	local p1, v1

	if d == 1 then -- Critically damped
		p1 = (offset * (1 + f * DeltaTime) + v0 * DeltaTime) * decay + g
		v1 = (v0 * (1 - f * DeltaTime) - offset * (f * f * DeltaTime)) * decay
	elseif d < 1 then -- Underdamped
		local c = math.sqrt(1 - d * d)

		local i = math.cos(f * c * DeltaTime)
		local j = math.sin(f * c * DeltaTime)

		-- Damping ratios approaching 1 can cause division by small numbers.
		-- To fix that, group terms around z=j/c and find an approximation for z.
		-- Start with the definition of z:
		--    z = sin(dt*f*c)/c
		-- Substitute a=dt*f:
		--    z = sin(a*c)/c
		-- Take the Maclaurin expansion of z with respect to c:
		--    z = a - (a^3*c^2)/6 + (a^5*c^4)/120 + O(c^6)
		--    z ≈ a - (a^3*c^2)/6 + (a^5*c^4)/120
		-- Rewrite in Horner form:
		--    z ≈ a + ((a*a)*(c*c)*(c*c)/20 - c*c)*(a*a*a)/6

		local z
		if c > EPS then
			z = j / c
		else
			local a = DeltaTime * f
			z = a + ((a * a) * (c * c) * (c * c) / 20 - c * c) * (a * a * a) / 6
		end

		-- Frequencies approaching 0 present a similar problem.
		-- We want an approximation for y as f approaches 0, where:
		--    y = sin(dt*f*c)/(f*c)
		-- Substitute b=dt*c:
		--    y = sin(b*c)/b
		-- Now reapply the process from z.

		local y
		if f * c > EPS then
			y = j / (f * c)
		else
			local b = f * c
			y = DeltaTime + ((DeltaTime * DeltaTime) * (b * b) * (b * b) / 20 - b * b) * (DeltaTime * DeltaTime * DeltaTime) / 6
		end

		p1 = (offset * (i + d * z) + v0 * y) * decay + g
		v1 = (v0 * (i - z * d) - offset * (z * f)) * decay
	else -- Overdamped
		local c = math.sqrt(d * d - 1)

		local r1 = -f * (d - c)
		local r2 = -f * (d + c)

		local co2 = (v0 - offset * r1) / (2 * f * c)
		local co1 = offset - co2

		local e1 = co1 * math.exp(r1 * DeltaTime)
		local e2 = co2 * math.exp(r2 * DeltaTime)

		p1 = e1 + e2 + g
		v1 = e1 * r1 + e2 * r2
	end

	local complete = math.abs(v1) < VELOCITY_THRESHOLD and math.abs(p1 - g) < POSITION_THRESHOLD
	return {
		complete = complete;
		value = complete and g or p1;
		velocity = v1;
	}
end

return Spring
