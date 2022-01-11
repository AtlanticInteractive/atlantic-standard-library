local Debug = require(script.Parent.Debug)
local Typer = require(script.Parent.Typer)

local TyperPlus = {}

function TyperPlus.Literally(LiteralValue: any)
	local TypeOf = typeof(LiteralValue)
	return {
		[Debug.InspectFormat(TypeOf .. " literally equal to %q", LiteralValue)] = function(Value, TypeOfString)
			return TypeOfString == TypeOf and Value == LiteralValue
		end;
	}
end

return setmetatable(TyperPlus, {__index = Typer})
