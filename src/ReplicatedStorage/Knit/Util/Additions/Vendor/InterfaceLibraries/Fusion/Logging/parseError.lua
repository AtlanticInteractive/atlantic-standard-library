--!strict

--[[
	An xpcall() error handler to collect and parse useful information about
	errors, such as clean messages and stack traces.

	TODO: this should have a 'type' field for runtime type checking!
]]

local Package = script.Parent.Parent
local Types = require(Package.Types)

local function parseError(err: string): Types.Error
	return {
		message = string.gsub(err, "^.+:%d+:%s*", "");
		raw = err;
		trace = debug.traceback(nil :: any, 2);
		type = "Error";
	}
end

return parseError
