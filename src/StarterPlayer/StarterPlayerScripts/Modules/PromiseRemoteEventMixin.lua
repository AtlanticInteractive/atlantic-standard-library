--[=[
	Intended for classes that extend BaseObject only
	@class PromiseRemoteEventMixin
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PromiseChild = require(ReplicatedStorage.Knit.Util.Additions.Promises.PromiseChild)

local PromiseRemoteEventMixin = {}

--[=[
	Adds the remote function mixin to a class

	```lua
	local BaseObject = require("BaseObject")

	local Bird = setmetatable({}, BaseObject)
	Bird.ClassName = "Bird"
	Bird.__index = Bird

	require("PromiseRemoteEventMixin"):Add(Bird, "BirdRemoteEvent")

	function Bird.new(inst)
		local self = setmetatable(BaseObject.new(inst), Bird)

		self:PromiseRemoteEvent():Then(function(remoteEvent)
			self._maid:GiveTask(remoteEvent.OnClientEvent:Connect(function(...)
				self:_handleRemoteEvent(...)
			end)
		end)

		return self
	end
	```

	@param class { _maid: Maid }
	@param remoteEventName string
]=]
function PromiseRemoteEventMixin:Add(Class, RemoteEventName)
	assert(type(Class) == "table", "Bad class")
	assert(type(RemoteEventName) == "string", "Bad remoteEventName")
	assert(not Class.PromiseRemoteEventMixin, "Class already has PromiseRemoteEventMixin defined")
	assert(not Class.RemoteEventName, "Class already has _remoteEventName defined")

	Class.PromiseRemoteEvent = self.PromiseRemoteEvent
	Class.RemoteEventName = RemoteEventName
end

--[=[
	Returns a promise that returns a remote event
	@return Promise<RemoteEvent>
]=]
function PromiseRemoteEventMixin:PromiseRemoteEvent()
	return self.Janitor:AddPromise(PromiseChild(self.Object, self.RemoteEventName))
end

return PromiseRemoteEventMixin
