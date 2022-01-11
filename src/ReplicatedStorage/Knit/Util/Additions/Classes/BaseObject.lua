--[=[
	A BaseObject basically just adds the `:Destroy()` interface, and a `Janitor`, along with an optional object it references.
	@class BaseObject
]=]

local Janitor = require(script.Parent.Parent.Parent.Janitor)

local BaseObject = {}
BaseObject.ClassName = "BaseObject"
BaseObject.__index = BaseObject

--[=[
	Constructs a new BaseObject.
	@param Object Instance?
	@return BaseObject
]=]
function BaseObject.new(Object: Instance?)
	return setmetatable({
		Janitor = Janitor.new();
		Object = Object;
	}, BaseObject)
end

--[=[
	Cleans up the BaseObject and sets the metatable to nil
]=]
function BaseObject:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
end

function BaseObject:__tostring()
	return "BaseObject"
end

export type BaseObject = typeof(BaseObject.new())
table.freeze(BaseObject)
return BaseObject
