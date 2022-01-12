--[=[
	[ContainerService](https://github.com/csqrl/containerservice-knit/) by csqrl. ContainerService is a Service and Controller pair for Sleitnick's Knit framework,
	which allows for selective replication to clients. This means that an Instance can be replicated to a specific client without it being replicated to any other client.

	ContainerService handles replication to individual clients.

	@server
	@class ContainerService
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local Enumeration = require(ReplicatedStorage.Knit.Util.Additions.Enumeration)
local Promise = require(ReplicatedStorage.Knit.Util.Promise)
local PromiseChildOfClass = require(ReplicatedStorage.Knit.Util.Additions.Promises.PromiseChildOfClass)
local Signal = require(ReplicatedStorage.Knit.Util.Signal)
local Typer = require(ReplicatedStorage.Knit.Util.Additions.Debugging.Typer)

local ContainerService = Knit.CreateService({
	Client = {};
	Name = "ContainerService";
})

ContainerService.Attribute = "__CONTAINER_ID__"
ContainerService.PendingContainers = {}

--[=[
	@prop Hashes {[UserId]: HashString}
	@within ContainerService
]=]
ContainerService.Hashes = {}

--[=[
	@prop InstanceReferences {[BaseInstance]: {[UserId]: CloneInstance}}
	@within ContainerService
]=]
ContainerService.InstanceReferences = {}

--[=[
	@prop RootContainers {[UserId]: RootContainerScreenGui}
	@within ContainerService
]=]
ContainerService.RootContainers = {}

--[=[
	@prop PendingContainerCompleted Signal<UserId: number, ContainerId: string>
	@within ContainerService
]=]
ContainerService.PendingContainerCompleted = Signal.new()

--[=[
	@prop RootContainerReady RemoteSignal<Hash: string>
	@tag Client
	@within ContainerService
]=]
ContainerService.Client.RootContainerReady = Knit.CreateSignal()

local PostSimulationEvent = RunService.Heartbeat
local function LinkToInstanceLite(Object: Instance, Function: () -> ())
	local Connection
	Connection = Object:GetPropertyChangedSignal("Parent"):Connect(function()
		PostSimulationEvent:Wait()
		if not Connection.Connected then
			Function()
		end
	end)
end

local function PlayerAdded(Player: Player)
	local ContainerHash = HttpService:GenerateGUID()
	local UserId = Player.UserId

	ContainerService.Hashes[UserId] = ContainerHash
	ContainerService.RootContainers[UserId] = Promise.new(function(Resolve)
		local Container = Instance.new("ScreenGui")
		Container.Name = ContainerHash
		Container.ResetOnSpawn = false

		PromiseChildOfClass(Player, "PlayerGui", 10):Then(function(PlayerGui: PlayerGui)
			Container.Parent = PlayerGui
		end):Catch(CatchFactory("PromiseChildOfClass")):Wait()

		Resolve(Container)
		ContainerService.Client.RootContainerReady:Fire(Player, ContainerHash)
	end)
end

local function PlayerRemoving(Player: Player)
	local UserId = Player.UserId
	ContainerService.Hashes[UserId] = nil
	ContainerService.RootContainers[UserId] = nil

	for InstanceReference, CloneReferences in next, ContainerService.InstanceReferences do
		for UserIdReference in next, CloneReferences do
			if UserIdReference == UserId then
				ContainerService.InstanceReferences[InstanceReference][UserIdReference] = nil
			end
		end
	end
end

--[=[
	Gets the Container for the given Player and ContainerId.
	@param Player Player
	@param ContainerId string
	@return Promise<Folder>
]=]
function ContainerService:GetContainer(Player: Player, ContainerId: string)
	local UserId = Player.UserId
	if not self.RootContainers[UserId] then
		return Enumeration.ContainerStatus.NotReady.Value
	end

	if not self.PendingContainers[UserId] then
		self.PendingContainers[UserId] = {}
	end

	return self.RootContainers[UserId]:Then(function(RootContainer)
		local Container = RootContainer:FindFirstChild(ContainerId)
		if Container then
			return Container
		else
			if self.PendingContainers[UserId][ContainerId] then
				return Promise.FromEvent(self.PendingContainerCompleted, function(PendingUserId, PendingContainerId)
					return PendingUserId == UserId and PendingContainerId == ContainerId
				end):Then(function()
					return self:GetContainer(Player, ContainerId)
				end)
			end

			self.PendingContainers[UserId][ContainerId] = true
			Container = Instance.new("Folder")
			Container:SetAttribute(self.Attribute, ContainerId)
			Container.Name = ContainerId
			Container.Parent = RootContainer

			self.PendingContainers[UserId][ContainerId] = nil
			self.PendingContainerCompleted:Fire(UserId, ContainerId)
			return Container
		end
	end)
end

--[=[
	Clears the Container for the given Player and ContainerId.
	@param Player Player
	@param ContainerId string
	@return Promise<void>
]=]
function ContainerService:ClearContainer(Player: Player, ContainerId: string)
	return self:GetContainer(Player, ContainerId):Then(function(Container: Folder)
		Container:ClearAllChildren()
	end)
end

--[=[
	Replicates the given Object to the Player with the ContainerId.
	@param Player Player
	@param ContainerId string
	@param Object Instance
	@return Promise<Instance>
]=]
function ContainerService:ReplicateTo(Player: Player, ContainerId: string, Object: Instance)
	local UserId = Player.UserId
	if not self.InstanceReferences[Object] then
		self.InstanceReferences[Object] = {}
	end

	if self.InstanceReferences[Object][UserId] then
		return Promise.Resolve(self.InstanceReferences[Object][UserId])
	end

	return self:GetContainer(Player, ContainerId):Then(function(Container: Folder)
		local CloneObject = Object:Clone()
		self.InstanceReferences[Object][UserId] = CloneObject
		CloneObject.Parent = Container

		LinkToInstanceLite(CloneObject, function()
			if self.InstanceReferences[Object][UserId] == CloneObject then
				self.InstanceReferences[Object][UserId] = nil
			end
		end)

		return CloneObject
	end)
end

--[=[
	Dereplicates the Object from the Player.
	@param Player Player
	@param Object Instance
]=]
function ContainerService:DereplicateFrom(Player: Player, Object: Instance)
	local UserId = Player.UserId
	local InstanceReference = self.InstanceReferences[Object]

	if InstanceReference and InstanceReference[UserId] then
		InstanceReference[UserId]:Destroy()
	end
end

--[=[
	Requests the root container hash for the player.
	@tag Client
	@param Player Player -- You do not need to pass this on the client, it'll automatically be passed.
	@return Hash string?
	@return StatusCode number
]=]
function ContainerService.Client:RequestRootContainerHash(Player: Player): (string?, number)
	local UserId = Player.UserId
	local RootContainerHash = self.Server.Hashes[UserId]

	if RootContainerHash then
		return RootContainerHash, Enumeration.ContainerStatus.Success.Value
	end

	return nil, Enumeration.ContainerStatus.NotReady.Value
end

ContainerService.GetContainer = Typer.PromiseAssignSignature(2, Typer.InstanceWhichIsAPlayer, Typer.String, ContainerService.GetContainer)
ContainerService.ClearContainer = Typer.PromiseAssignSignature(2, Typer.InstanceWhichIsAPlayer, Typer.String, ContainerService.ClearContainer)
ContainerService.ReplicateTo = Typer.PromiseAssignSignature(2, Typer.InstanceWhichIsAPlayer, Typer.String, Typer.Instance, ContainerService.DereplicateFrom)
ContainerService.DereplicateFrom = Typer.AssignSignature(2, Typer.InstanceWhichIsAPlayer, Typer.Instance, ContainerService.DereplicateFrom)
ContainerService.Client.RequestRootContainerHash = Typer.AssignSignature(2, Typer.InstanceWhichIsAPlayer, ContainerService.Client.RequestRootContainerHash)

function ContainerService:KnitInit()
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerAdded, Player)
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
end

return ContainerService
