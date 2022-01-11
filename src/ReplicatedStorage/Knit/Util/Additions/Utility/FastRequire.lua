local RequireCache = {}

local function FastRequire(ModuleScript: ModuleScript)
	local ModuleData = RequireCache[ModuleScript]
	if ModuleData ~= nil then
		return ModuleData
	else
		ModuleData = require(ModuleScript)
		if ModuleData == nil then
			error(string.format("Cannot return nil as a value, please fix: %s", ModuleScript:GetFullName()))
		end

		RequireCache[ModuleScript] = ModuleData
		return ModuleData
	end
end

return FastRequire
