local Instant = {}
Instant.ClassName = "Instant"
Instant.__index = Instant

function Instant.new(TargetValue)
	return setmetatable({
		_TargetValue = TargetValue;
	}, Instant)
end

function Instant:Step()
	return {
		complete = true;
		value = self._TargetValue;
	}
end

return Instant
