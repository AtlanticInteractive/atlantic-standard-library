--[=[
	Bind class to Roblox Instance

	```lua
	-- Setup a class!
	local MyClass = {}
	MyClass.__index = MyClass

	function MyClass.new(robloxInstance)
		print("New tagged instance of ", robloxInstance)
		return setmetatable({}, MyClass)
	end

	function MyClass:Destroy()
		print("Cleaning up")
		setmetatable(self, nil)
	end

	-- bind to every instance with tag of "TagName"!
	local binder = Binder.new("TagName", MyClass)
	binder:Start() -- listens for new instances and connects events
	```

	@class Binder
]=]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local PromiseBoundClass = require(script.Parent.Parent.Parent.Promises.PromiseBoundClass)
local Signal = require(script.Parent.Parent.Parent.Parent.Signal)

local Binder = {}
Binder.ClassName = "Binder"
Binder.__index = Binder

--[=[
	Constructor for a binder
	@type BinderContructor (Instance, ...: any) -> T | { new: (Instance, ...: any) } | { Create(self, Instance, ...: any) }
	@within Binder
]=]

--[=[
	Constructs a new binder object.

	```lua
	local binder = Binder.new("Bird", function(inst)
		print("Wow, a new bird!", inst)

		return {
			Destroy = function()
				print("Uh oh, the bird is gone!")
			end;
		}
	end)
	binder:Start()
	```
	@param tagName string -- Name of the tag to bind to. This uses CollectionService's tag system
	@param constructor BinderContructor
	@param ... any -- Variable arguments that will be passed into the constructor
	@return Binder<T>
]=]
function Binder.new(TagName, Constructor, ...)
	local self = setmetatable({
		Janitor = Janitor.new();
		TagName = TagName or error("Bad argument 'tagName', expected string");
		Constructor = Constructor or error("Bad argument 'constructor', expected table or function");

		InstanceToClass = {}; -- [inst] = class
		AllClassSet = {}; -- [class] = true
		PendingInstanceSet = {}; -- [inst] = true

		Listeners = {}; -- [inst] = callback
		Arguments = {...};
	}, Binder)

	task.delay(5, function()
		if not self.Loaded then
			warn(string.format("Binder %q is not loaded. Call :Start() on it!", self.TagName))
		end
	end)

	return self
end

--[=[
	Retrieves whether or not the given value is a binder.

	@param value any
	@return boolean true or false, whether or not it is a value
]=]
function Binder.Is(Value)
	-- stylua: ignore
	return type(Value) == "table"
		and type(Value.Start) == "function"
		and type(Value.GetTag) == "function"
		and type(Value.GetConstructor) == "function"
		and type(Value.ObserveInstance) == "function"
		and type(Value.GetClassAddedSignal) == "function"
		and type(Value.GetClassRemovingSignal) == "function"
		and type(Value.GetClassRemovedSignal) == "function"
		and type(Value.GetAll) == "function"
		and type(Value.GetAllSet) == "function"
		and type(Value.Bind) == "function"
		and type(Value.Unbind) == "function"
		and type(Value.BindClient) == "function"
		and type(Value.UnbindClient) == "function"
		and type(Value.Get) == "function"
		and type(Value.Promise) == "function"
		and type(Value.Destroy) == "function"
end

--[=[
	Listens for new instances and connects to the GetInstanceAddedSignal() and removed signal!
]=]
function Binder:Start()
	if self.Loaded then
		return
	end

	self.Loaded = true
	for _, Object in ipairs(CollectionService:GetTagged(self.TagName)) do
		task.spawn(self._Add, self, Object)
	end

	self.Janitor:Add(CollectionService:GetInstanceAddedSignal(self.TagName):Connect(function(Object)
		self:_Add(Object)
	end), "Disconnect")

	self.Janitor:Add(CollectionService:GetInstanceRemovedSignal(self.TagName):Connect(function(Object)
		self:_Remove(Object)
	end), "Disconnect")
end

--[=[
	Returns the tag name that the binder has.
	@return string
]=]
function Binder:GetTag()
	warn("Binder:GetTag() is deprecated.")
	return self.TagName
end

--[=[
	Returns whatever was set for the construtor. Used for meta-analysis of
	the binder, such as extracting if parameters are allowed.

	@return BinderContructor
]=]
function Binder:GetConstructor()
	warn("Binder:GetConstructor() is deprecated.")
	return self.Constructor
end

--[=[
	Fired when added, and then after removal, but before destroy!

	@param inst Instance
	@param callback function
	@return function -- Cleanup function
]=]
function Binder:ObserveInstance(Object, Function)
	self.Listeners[Object] = self.Listeners[Object] or {}
	self.Listeners[Object][Function] = true

	return function()
		if not self.Listeners[Object] then
			return
		end

		self.Listeners[Object][Function] = nil
		if not next(self.Listeners[Object]) then
			self.Listeners[Object] = nil
		end
	end
end

--[=[
	Returns a new signal that will fire whenever a class is bound to the binder

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	birdBinder:GetClassAddedSignal():Connect(function(bird)
		bird:Squack() -- Make the bird squack when it's first spawned
	end)

	-- Load all birds
	birdBinder:Start()
	```

	@return Signal<T>
]=]
function Binder:GetClassAddedSignal()
	if self.ClassAddedSignal then
		return self.ClassAddedSignal
	end

	self.ClassAddedSignal = Signal.new(self.Janitor) -- :fire(class, inst)
	return self.ClassAddedSignal
end

--[=[
	Returns a new signal that will fire whenever a class is removing from the binder.

	@return Signal<T>
	]=]
function Binder:GetClassRemovingSignal()
	if self.ClassRemovingSignal then
		return self.ClassRemovingSignal
	end

	self.ClassRemovingSignal = Signal.new(self.Janitor) -- :fire(class, inst)
	return self.ClassRemovingSignal
end

--[=[
	Returns a new signal that will fire whenever a class is removed from the binder.

	@return Signal<T>
]=]
function Binder:GetClassRemovedSignal()
	if self.ClassRemovedSignal then
		return self.ClassRemovedSignal
	end

	self.ClassRemovedSignal = Signal.new(self.Janitor) -- :fire(class, inst)
	return self.ClassRemovedSignal
end

--[=[
	Returns all of the classes in a new table.

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	-- Update every bird every frame
	RunService.Stepped:Connect(function()
		for _, bird in pairs(birdBinder:GetAll()) do
			bird:Update()
		end
	end)

	birdBinder:Start()
	```

	@return {T}
]=]
function Binder:GetAll()
	local All = {}
	for Class in next, self.AllClassSet do
		table.insert(All, Class)
	end

	return All
end

--[=[
	Faster method to get all items in a binder

	```lua
	local birdBinder = Binder.new("Bird", require("Bird")) -- Load bird into binder

	-- Update every bird every frame
	RunService.Stepped:Connect(function()
		for bird, _ in pairs(birdBinder:GetAllSet()) do
			bird:Update()
		end
	end)

	birdBinder:Start()
	```

	:::warning
	Do not mutate this set directly
	:::

	@return { [T]: boolean }
]=]
function Binder:GetAllSet()
	return self.AllClassSet
end

--[=[
	Binds an instance to this binder using collection service and attempts
	to return it if it's bound properly. See BinderUtils.promiseBoundClass() for a safe
	way to retrieve it.

	:::warning
	Do not assume that a bound object will be retrieved
	:::

	@server
	@param inst Instance -- Instance to check
	@return T? -- Bound class
]=]
function Binder:Bind(Object)
	if RunService:IsClient() then
		warn(string.format("[Binder.Bind] - Bindings '%s' done on the client! Will be disrupted upon server replication! %s", self.TagName, debug.traceback()))
	end

	CollectionService:AddTag(Object, self.TagName)
	return self:Get(Object)
end

--[=[
	Unbinds the instance by removing the tag.

	@server
	@param inst Instance -- Instance to unbind
]=]
function Binder:Unbind(Object)
	assert(typeof(Object) == "Instance", "Bad inst'")

	if RunService:IsClient() then
		warn(string.format("[Binder.Bind] - Unbinding '%s' done on the client! Might be disrupted upon server replication! %s", self.TagName, debug.traceback()))
	end

	CollectionService:RemoveTag(Object, self.TagName)
end

--[=[
	See :Bind(). Acknowledges the risk of doing this on the client.

	Using this acknowledges that we're intentionally binding on a safe client object,
	i.e. one without replication. If another tag is changed on this instance, this tag will be lost/changed.

	@client
	@param inst Instance -- Instance to bind
	@return T? -- Bound class (potentially)
]=]
function Binder:BindClient(Object)
	if not RunService:IsClient() then
		warn(string.format("[Binder.BindClient] - Bindings '%s' done on the server! Will be replicated!", self.TagName))
	end

	CollectionService:AddTag(Object, self.TagName)
	return self:Get(Object)
end

--[=[
	See Unbind(), acknowledges risk of doing this on the client.

	@client
	@param inst Instance -- Instance to unbind
]=]
function Binder:UnbindClient(Object)
	assert(typeof(Object) == "Instance", "Bad inst")
	CollectionService:RemoveTag(Object, self.TagName)
end

--[=[
	Returns a instance of the class that is bound to the instance given.

	@param inst Instance -- Instance to check
	@return T?
]=]
function Binder:Get(Object)
	assert(typeof(Object) == "Instance", "Argument 'inst' is not an Instance")
	return self.InstanceToClass[Object]
end

--[=[
	Returns a promise which will resolve when the instance is bound.

	@param inst Instance -- Instance to check
	@param cancelToken? CancelToken
	@return Promise<T>
]=]
function Binder:Promise(Object)
	assert(typeof(Object) == "Instance", "Argument 'inst' is not an Instance")
	return PromiseBoundClass(self, Object)
end

function Binder:_Add(Object)
	assert(typeof(Object) == "Instance", "Argument 'inst' is not an Instance")

	if self.InstanceToClass[Object] then
		-- https://devforum.roblox.com/t/double-firing-of-collectionservice-getinstanceaddedsignal-when-applying-tag/244235
		return
	end

	if self.PendingInstanceSet[Object] == true then
		warn("[Binder._add] - Reentered add. Still loading, probably caused by error in constructor.")
		return
	end

	self.PendingInstanceSet[Object] = true

	local Class
	if type(self.Constructor) == "function" then
		Class = self.Constructor(Object, table.unpack(self.Arguments))
	elseif self.Constructor.Create then
		Class = self.Constructor:Create(Object, table.unpack(self.Arguments))
	else
		Class = self.Constructor.new(Object, table.unpack(self.Arguments))
	end

	if self.PendingInstanceSet[Object] ~= true then
		-- Got GCed in the process of loading?!
		-- Constructor probably yields. Yikes.
		warn(string.format("[Binder._add] - Failed to load instance %q of %q, removed while loading!", Object:GetFullName(), tostring(type(self.Constructor) == "table" and self.Constructor.ClassName or self.Constructor)))
		return
	end

	self.PendingInstanceSet[Object] = nil
	assert(self.InstanceToClass[Object] == nil, "Overwrote")

	Class = Class or {}

	-- Add to state
	self.AllClassSet[Class] = true
	self.InstanceToClass[Object] = Class

	-- Fire events
	local Listeners = self.Listeners[Object]
	if Listeners then
		for Function in next, Listeners do
			task.spawn(Function, Class)
		end
	end

	if self.ClassAddedSignal then
		self.ClassAddedSignal:Fire(Class, Object)
	end
end

function Binder:_Remove(Object)
	self.PendingInstanceSet[Object] = nil

	local Class = self.InstanceToClass[Object]
	if Class == nil then
		return
	end

	-- Fire off events
	if self.ClassRemovingSignal then
		self.ClassRemovingSignal:Fire(Class, Object)
	end

	-- Clean up state
	self.InstanceToClass[Object] = nil
	self.AllClassSet[Class] = nil

	-- Fire listener here
	local Listeners = self.Listeners[Object]
	if Listeners then
		for Function in next, Listeners do
			task.spawn(Function, nil)
		end
	end

	if type(Class) == "function" or typeof(Class) == "RBXScriptConnection" or type(Class) == "table" and type(Class.Destroy) == "function" or typeof(Class) == "Instance" then
		if type(Class) == "function" then
			Class()
		elseif typeof(Class) == "RBXScriptConnection" then
			Class:Disconnect()
		elseif type(Class) == "table" and type(Class.Destroy) == "function" then
			Class:Destroy()
			-- selene: allow(if_same_then_else)
		elseif typeof(Class) == "Instance" then
			Class:Destroy()
		else
			error("Bad job")
		end
	end

	-- Fire off events
	if self.ClassRemovedSignal then
		self.ClassRemovedSignal:Fire(Class, Object)
	end
end

--[=[
	Cleans up all bound classes, and disconnects all events.
]=]
function Binder:Destroy()
	local Object, Class = next(self.InstanceToClass)
	while Class ~= nil do
		self:_Remove(Object)
		assert(self.InstanceToClass[Object] == nil, "Failed to remove")
		Object, Class = next(self.InstanceToClass)
	end

	-- Disconnect events
	self.Janitor:Cleanup()
end

return Binder
