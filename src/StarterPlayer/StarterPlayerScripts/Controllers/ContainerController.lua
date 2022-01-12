--[=[
	[ContainerService](https://github.com/csqrl/containerservice-knit/) by csqrl. ContainerService is a Service and Controller pair for Sleitnick's Knit framework,
	which allows for selective replication to clients. This means that an Instance can be replicated to a specific client without it being replicated to any other client.

	ContainerController receives replicated instances from the server and emits events regarding transactions.

	@client
	@class ContainerController
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local Enumeration = require(ReplicatedStorage.Knit.Util.Additions.Enumeration)
local GetService = require(ReplicatedStorage.Knit.Util.GetService)
local Promise = require(ReplicatedStorage.Knit.Util.Promise)
local PromiseChild = require(ReplicatedStorage.Knit.Util.Additions.Promises.PromiseChild)
local PromiseChildOfClass = require(ReplicatedStorage.Knit.Util.Additions.Promises.PromiseChildOfClass)
local Signal = require(ReplicatedStorage.Knit.Util.Signal)

local ContainerController = Knit.CreateController({
	Name = "ContainerController";
})

ContainerController.Attribute = "__CONTAINER_ID__"
ContainerController.ContainerPendingCompleted = Signal.new()
ContainerController.ContainersPending = {}
ContainerController.RootContainerPending = nil
ContainerController.RootContainerPendingCompleted = Signal.new()

--[=[
	@prop Containers {[ContainerIdString]: ContainerFolder}
	@within ContainerController
]=]
ContainerController.Containers = {}

--[=[
	@prop ItemReplicated Signal<ContainerId: string, Instance: Instance>
	@within ContainerController
]=]
ContainerController.ItemReplicated = Signal.new()

--[=[
	@prop RootContainer ScreenGui?
	@within ContainerController
]=]
ContainerController.RootContainer = nil

local PostSimulation = RunService.Heartbeat
local function LinkToInstanceLite(Object: Instance, Function: () -> ())
	local Connection
	Connection = Object:GetPropertyChangedSignal("Parent"):Connect(function()
		PostSimulation:Wait()
		if not Connection.Connected then
			Function()
		end
	end)
end

local function RequestRootContainerHashPromise()
	return Promise.new(function(Resolve)
		Resolve(GetService.Default("ContainerService"):RequestRootContainerHash())
	end)
end

--[=[
	Used to get the RootContainer.
	@return Promise<ScreenGui>
]=]
function ContainerController:GetRootContainer()
	local ContainerService = GetService.Default("ContainerService")

	return Promise.new(function(Resolve, Reject)
		if self.RootContainer then
			return Resolve(self.RootContainer)
		end

		if self.RootContainerPending then
			return Resolve(Promise.FromEvent(self.RootContainerPendingCompleted))
		end

		self.RootContainerPending = true

		RequestRootContainerHashPromise():Then(function(Hash, Status)
			return assert(Hash, Status)
		end):Catch(function(Error)
			local ErrorEnumeration = Enumeration.ContainerStatus:Cast(Error)
			if ErrorEnumeration and ErrorEnumeration == Enumeration.ContainerStatus.NotReady.Value then
				return Promise.FromEvent(ContainerService.RootContainerReady)
			end

			warn("Encountered an error waiting for hash:", Error)
			Reject(Error)
		end):Then(function(Hash)
			PromiseChildOfClass(Knit.Player, "PlayerGui", 10):Then(function(PlayerGui: PlayerGui)
				PromiseChild(PlayerGui, Hash, 10):Then(function(RootContainer)
					self.RootContainer = RootContainer
					self.RootContainerPending = nil

					Resolve(RootContainer)

					self.RootContainerPendingCompleted:Fire(RootContainer)
					self.RootContainerPendingCompleted:Destroy()
					self.RootContainerPendingCompleted = nil

					RootContainer.Parent = ServerStorage

					for _, Child in ipairs(RootContainer:GetChildren()) do
						if Child:GetAttribute(self.Attribute) then
							task.spawn(self.Container, self, Child.Name)
						end
					end

					RootContainer.ChildAdded:Connect(function(Child)
						if Child:GetAttribute(self.Attribute) then
							self:GetContainer(Child.Name)
						end
					end)
				end):Catch(CatchFactory("PromiseChild"))
			end):Catch(CatchFactory("PromiseChildOfClass"))
		end)
	end)
end

local function ProcessChildAdded(ContainerId: string, Child: Instance)
	PostSimulation:Wait()
	ContainerController.ItemReplicated:Fire(ContainerId, Child)
end

--[=[
	Used to get a container for the given ContainerId.
	@param ContainerId string
	@return Promise<Folder>
]=]
function ContainerController:GetContainer(ContainerId: string)
	if self.Containers[ContainerId] then
		return Promise.Resolve(self.Containers[ContainerId])
	end

	return self:GetRootContainer():Then(function(RootContainer)
		if self.ContainersPending[ContainerId] then
			return Promise.FromEvent(self.ContainerPendingCompleted, function(PendingId, PendingContainer)
				if PendingId == ContainerId then
					return PendingContainer
				end
			end)
		end

		self.ContainersPending[ContainerId] = true
		return PromiseChild(RootContainer, ContainerId, 10):Then(function(Container)
			self.Containers[ContainerId] = Container
			self.ContainerPendingCompleted:Fire(ContainerId, Container)

			LinkToInstanceLite(Container, function()
				self.Containers[ContainerId] = nil
			end)

			for _, Child in ipairs(Container:GetChildren()) do
				task.spawn(ProcessChildAdded, ContainerId, Child)
			end

			Container.ChildAdded:Connect(function(Child)
				ProcessChildAdded(ContainerId, Child)
			end)

			return Container
		end):Catch(CatchFactory("PromiseChild"))
	end)
end

function ContainerController:KnitStart()
	self:GetRootContainer():Catch(CatchFactory("ContainerController:GetRootContainer"))
end

return ContainerController
