--[=[
	@class IKAimPositionPriorities
]=]

local IKAimPositionPriorities = {
	DEFAULT = 0;
	LOW = 1000;
	MEDIUM = 3000;
	HIGH = 4000;
}

table.freeze(IKAimPositionPriorities)
return IKAimPositionPriorities
