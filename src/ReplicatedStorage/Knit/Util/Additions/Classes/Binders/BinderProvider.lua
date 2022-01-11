--[=[
	Provides a basis for binders that can be retrieved anywhere
	@class BinderProvider
]=]

local Debug = require(script.Parent.Parent.Parent.Debugging.Debug)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)

local BinderProvider = {}
BinderProvider.ClassName = "BinderProvider"

--[=[
	Constructs a new BinderProvider.

	```lua
	local serviceBag = ServiceBag.new()

	-- Usually in a separate file!
	local binderProvider = BinderProvider.new(function(self, serviceBag)
		serviceBag:Add(Binder.new("Bird", require("Bird")))
	end)

	-- Retrieve binders
	local binders = serviceBag:GetService(binderProvider)

	-- Runs the game (including binders)
	serviceBag:Init()
	serviceBag:Start()
	```

	@param initMethod (self, serviceBag: ServiceBag)
	@return BinderProvider
]=]
function BinderProvider.new(InitializeMethod)
	return setmetatable({
		Binders = nil;
		BindersAddedPromise = nil;
		StartPromise = nil;

		Initialized = false;
		InitializeMethod = InitializeMethod;
		Started = false;
	}, BinderProvider)
end

function BinderProvider.Is(Value)
	return type(Value) == "table" and getmetatable(Value) == BinderProvider
end

--[=[
	Resolves to the given binder given the binderName.

	@param BinderName string
	@return Promise<Binder<T>>
]=]
function BinderProvider:PromiseBinder(BinderName: string)
	if self.BindersAddedPromise.Status == Promise.Status.Resolved then
		local Binder = self:Get(BinderName)
		if Binder then
			return Promise.Resolve(Binder)
		else
			return Promise.Reject()
		end
	end

	return self.BindersAddedPromise:Then(function()
		local Binder = self:Get(BinderName)
		if Binder then
			return Binder
		else
			return Promise.Reject()
		end
	end)
end

--[=[
	Initializes itself and all binders

	@param ... any
]=]
function BinderProvider:Initialize(...)
	Debug.Assert(not self.Initialized, "Already initialized.")
	self.Binders = {}
	self.Initialized = true

	self.BindersAddedPromise = Promise.new()
	self.StartPromise = Promise.new()

	self.InitializeMethod(self, ...)
	self.BindersAddedPromise:Resolve()
	return self
end

--[=[
	Returns a promise that will resolve once all binders are added.

	@return Promise
]=]
function BinderProvider:PromiseBindersAdded()
	return Debug.Assert(self.BindersAddedPromise, "No BindersAddedPromise.")
end

--[=[
	Returns a promise that will resolve once all binders are started.

	@return Promise
]=]
function BinderProvider:PromiseBindersStarted()
	return Debug.Assert(self.StartPromise, "No StartPromise.")
end

--[=[
	Starts all of the binders.
]=]
function BinderProvider:Start()
	Debug.Assert(self.Initialized, "Not initialized")
	Debug.Assert(not self.Started, "Already started")

	self.Started = true
	for _, Binder in ipairs(self.Binders) do
		Binder:Start()
	end

	self.StartPromise:Resolve()
	return self
end

function BinderProvider:__index(Index)
	if BinderProvider[Index] then
		return BinderProvider[Index]
	end

	Debug.Error("%q not a valid binder", Index)
end

--[=[
	Retrieves a binder given a tagName

	@param TagName string
	@return Binder<T>?
]=]
function BinderProvider:Get(TagName: string)
	Debug.Assert(type(TagName) == "string", "tagName must be a string")
	return rawget(self, TagName)
end

--[=[
	Adds a binder given a tag name.
	@param Binder Binder<T>
]=]
function BinderProvider:Add(Binder)
	Debug.Assert(not self.Started, "Already inited")
	Debug.Assert(not self:Get(Binder.TagName), "Binder already exists")

	table.insert(self.Binders, Binder)
	self[Binder.TagName] = Binder
end

function BinderProvider:__tostring()
	return "BinderProvider"
end

export type BinderProvider = typeof(BinderProvider.new(function(_self: BinderProvider) end))
table.freeze(BinderProvider)
return BinderProvider
