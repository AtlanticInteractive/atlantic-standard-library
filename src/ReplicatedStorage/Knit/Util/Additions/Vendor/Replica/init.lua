-- Robert Tulley
-- MIT license
-- See Documentation: https://github.com/headjoe3/Replica/blob/master/docs/Replica.md

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Context = require(script.Context)
local GetFirstChild = require(script.Parent.Parent.Utility.GetFirstChild)
local Promise = require(script.Parent.Parent.Parent.Promise)
local PromiseChild = require(script.Parent.Parent.Promises.PromiseChild)
local Replicant = require(script.Replicant)
local SafeThread = require(script.SafeThread)
local Signal = require(script.Parent.Parent.Parent.Signal)
local StringBuilder = require(script.Parent.Parent.Classes.StringBuilder)

local Replicators = script.Replicators

local COLLECTION_TAG = "ReplicaRegisteredKeyInstance"
local INSTANCE_GUID_MATCHING_BUFFER_TIMEOUT = 30

local StaticContainers = {
	game:GetService("Workspace");
	ReplicatedStorage;
	game:GetService("ServerStorage");
}

local UseInStaticContainer = false

for Index = 1, #StaticContainers do
	if script:IsDescendantOf(StaticContainers[Index]) then
		UseInStaticContainer = true
		break
	end
end

if not UseInStaticContainer then
	error("Replica package must be a descendant of a replicated static container (e.g. ReplicatedStorage)")
end

local INSTANCE_GUID_PREFIX = "_InstanceGuid_"
local function NewInstanceGuid(): string
	local String = StringBuilder.new():Append(INSTANCE_GUID_PREFIX)
	for _ = 1, 30 do
		if math.random() > 0.5 then
			String:Append(string.char(math.random(65, 90)))
		else
			String:Append(string.char(math.random(97, 122)))
		end
	end

	return String:ToString()
end

local function IsInstanceGuid(Key: string)
	return string.sub(Key, 1, #INSTANCE_GUID_PREFIX) == INSTANCE_GUID_PREFIX
end

local Registry = {}
local InstanceGuidMap = {}
local GuidInstanceMap = {}
local InstanceGuidTrackers = {}

local _, Replicants = PromiseChild(script, "Replicants", 10):Wait()

local Replica = {}
Replica.Array = require(Replicants:WaitForChild("Array"))
Replica.FactoredNor = require(Replicants:WaitForChild("FactoredNor"))
Replica.FactoredOr = require(Replicants:WaitForChild("FactoredOr"))
Replica.FactoredSum = require(Replicants:WaitForChild("FactoredSum"))
Replica.Map = require(Replicants:WaitForChild("Map"))

function Replica.Register(KeyRef, RegisteredReplicant)
	local Key
	if type(KeyRef) == "string" or type(KeyRef) == "number" then
		Key = KeyRef
	elseif typeof(KeyRef) == "Instance" then
		Key = NewInstanceGuid()

		if KeyRef:IsDescendantOf(game) then
			GuidInstanceMap[Key] = KeyRef
			InstanceGuidMap[KeyRef] = Key
			CollectionService:AddTag(KeyRef, COLLECTION_TAG)

			-- Unregister if the instance is destroyed or leaves the game tree
			InstanceGuidTrackers[KeyRef] = KeyRef.AncestryChanged:Connect(function()
				if not KeyRef:IsDescendantOf(game) then
					Replica.Unregister(KeyRef)
				end
			end)
		else
			error("Cannot register on instances outside of the DataModel")
		end
	else
		error("Invalid key '" .. tostring(KeyRef) .. "'; only strings, numbers, or Instances can be used as Replica registry keys")
	end

	if type(RegisteredReplicant) ~= "table" or not rawget(RegisteredReplicant, "_IsReplicant") then
		error("Bad argument #2 for Replica.Register (Replicant expected, got " .. typeof(RegisteredReplicant) .. ")")
	end

	if RegisteredReplicant.Context.Active then
		error("Replicant was already registered, or is nested in a registered context")
	end

	if RunService:IsServer() then
		local Existing = Registry[Key]
		if Existing ~= nil then
			warn("Replicant replaced at duplicate key '" .. Key .. "' because it was never unregistered")
			Replica.Unregister(KeyRef)
		end

		local Replicator = Instance.new("RemoteEvent")
		Replicator.Name = Key
		Replicator.Parent = Replicators

		Registry[Key] = RegisteredReplicant
		RegisteredReplicant:_SetContext(Context.new(RegisteredReplicant, {}, RegisteredReplicant.Config, true, Key))

		Replica.ReplicantRegistered:Fire(RegisteredReplicant, KeyRef)
	else
		error("Replica.Register can only be called on the server")
	end
end

function Replica.Unregister(KeyRef)
	local Key
	if type(KeyRef) == "string" then
		Key = KeyRef
		if IsInstanceGuid(Key) then
			error("Cannot explicitly unregister instance-bound keys")
		end
	elseif type(KeyRef) == "number" then
		Key = KeyRef
	elseif typeof(KeyRef) == "Instance" then
		Key = InstanceGuidMap[KeyRef]
		if not Key then
			return
		end
	end

	if RunService:IsServer() then
		local Replicator = Replicators:FindFirstChild(Key)
		if Replicator then
			Replicator:Destroy()
		end

		local RegisteredReplicant = Registry[Key]
		if RegisteredReplicant ~= nil then
			Replica.ReplicantWillUnregister:Fire(RegisteredReplicant, KeyRef)

			if typeof(KeyRef) == "Instance" then
				GuidInstanceMap[Key] = nil
				InstanceGuidMap[KeyRef] = nil
				CollectionService:RemoveTag(KeyRef, COLLECTION_TAG)

				if InstanceGuidTrackers[KeyRef] ~= nil then
					InstanceGuidTrackers[KeyRef]:Disconnect()
					InstanceGuidTrackers[KeyRef] = nil
				end
			end

			Registry[Key]:Destroy()
			Registry[Key] = nil
			Replica.ReplicantUnregistered:Fire(RegisteredReplicant, KeyRef)
		end
	else
		error("Replica.Unregister can only be called on the server")
	end
end

function Replica.WaitForRegistered(KeyRef, Timeout)
	local RegisteredReplicant = Replica.GetRegistered(KeyRef)
	if RegisteredReplicant ~= nil then
		return RegisteredReplicant
	end

	local Thread = SafeThread.Running()
	local GotReturnValue = false
	local Connection = Replica.ReplicantRegistered:Connect(function(NewReplicant, OtherKey)
		if not GotReturnValue and OtherKey == KeyRef then
			GotReturnValue = true
			SafeThread.Resume(Thread, NewReplicant)
		end
	end)

	if Timeout ~= nil then
		task.delay(Timeout, function()
			if not GotReturnValue then
				GotReturnValue = true
				SafeThread.Resume(Thread, nil)
			end
		end)
	end

	local ReturnValue = SafeThread.Yield()
	Connection:Disconnect()

	if type(ReturnValue) == "table" and rawget(ReturnValue, "_IsReplicant") == true then
		return ReturnValue
	else
		return nil
	end
end

function Replica.PromiseRegistered(KeyRef, Timeout)
	local RegisteredReplicant = Replica.GetRegistered(KeyRef)
	if RegisteredReplicant ~= nil then
		return Promise.Resolve(Replicant)
	end

	return Promise.Defer(function(Resolve, Reject)
		local Thread = SafeThread.Running()
		local GotReturnValue = false
		local Connection = Replica.ReplicantRegistered:Connect(function(NewReplicant, OtherKey)
			if not GotReturnValue and OtherKey == KeyRef then
				GotReturnValue = true
				SafeThread.Resume(Thread, NewReplicant)
			end
		end)

		if Timeout ~= nil then
			task.delay(Timeout, function()
				if not GotReturnValue then
					GotReturnValue = true
					SafeThread.Resume(Thread, nil)
				end
			end)
		end

		local ReturnValue = SafeThread.Yield()
		Connection:Disconnect()

		if type(ReturnValue) == "table" and rawget(ReturnValue, "_IsReplicant") == true then
			Resolve(ReturnValue)
		else
			Reject("Couldn't get value!")
		end
	end)
end

function Replica.GetRegistered(KeyRef)
	return Registry[KeyRef] or (InstanceGuidMap[KeyRef] and Registry[InstanceGuidMap[KeyRef]])
end

Replica.Deserialize = Replicant.FromSerialized
Replica.ReplicantRegistered = Signal.new()
Replica.ReplicantWillUnregister = Signal.new()
Replica.ReplicantUnregistered = Signal.new()

-- Register replicants created on the server
if RunService:IsClient() then
	task.spawn(function()
		PromiseChild(script, "Replicators", 10):Expect()
		local BaseReplicantEvent = GetFirstChild(GetFirstChild(ReplicatedStorage, "RemoteEvents", "Folder"), "RemoteEvent", "ReplicateBaseReplicant")
		local GetGuidFunction = GetFirstChild(GetFirstChild(ReplicatedStorage, "RemoteFunctions", "Folder"), "RemoteFunctions", "GetRegisteredGuid")

		-- We want to match instances tagged in CollectionService with string GUID keys.
		local CollectionBuffer = {}
		local InstanceGuidRegisteredSignal = Signal.new()
		local function MatchInstanceGuid(Object, GuidKey, RegisteredReplicant)
			CollectionBuffer[GuidKey] = nil

			InstanceGuidMap[Object] = GuidKey
			GuidInstanceMap[GuidKey] = Object

			Registry[GuidKey] = RegisteredReplicant
			Replica.ReplicantRegistered:Fire(RegisteredReplicant, Object)
		end

		local function DeregisterReplicant(Key)
			if not IsInstanceGuid(Key) then
				local RegisteredReplicant = Registry[Key]
				if RegisteredReplicant ~= nil then
					Replica.ReplicantWillUnregister:Fire(RegisteredReplicant, Key)

					RegisteredReplicant:Destroy()
					Registry[Key] = nil

					Replica.ReplicantUnregistered:Fire(RegisteredReplicant, Key)
				end
			else
				local StillInBuffer = CollectionBuffer[Key]
				if StillInBuffer then
					StillInBuffer:Destroy()
					CollectionBuffer[Key] = nil
				else
					local RegisteredReplicant = Registry[Key]
					if RegisteredReplicant then
						local Object = GuidInstanceMap[Key]
						InstanceGuidMap[Object] = nil
						GuidInstanceMap[Key] = nil

						Replica.ReplicantWillUnregister:Fire(RegisteredReplicant, Key)

						Registry[Key]:Destroy()
						Registry[Key] = nil

						Replica.ReplicantUnregistered:Fire(RegisteredReplicant, Object)
					end
				end
			end
		end

		-- Collection service entry point
		local function HandleCollectionInstance(Object)
			local GuidKey = GetGuidFunction:InvokeServer(Object)

			if GuidKey then
				if CollectionBuffer[GuidKey] ~= nil then
					MatchInstanceGuid(Object, GuidKey, CollectionBuffer[GuidKey])
				else
					local StartTime = time()
					repeat
						local RegisteredReplicant, Key = InstanceGuidRegisteredSignal:Wait()
						if Key == GuidKey then
							MatchInstanceGuid(Object, GuidKey, RegisteredReplicant)
						end
					until Key == GuidKey or not Object:IsDescendantOf(game) or (time() - StartTime > INSTANCE_GUID_MATCHING_BUFFER_TIMEOUT)
				end
			end
		end

		CollectionService:GetInstanceAddedSignal(COLLECTION_TAG):Connect(HandleCollectionInstance)
		for _, Object in ipairs(CollectionService:GetTagged(COLLECTION_TAG)) do
			task.spawn(HandleCollectionInstance, Object)
		end

		-- Listen to the server for any registered keys
		BaseReplicantEvent.OnClientEvent:Connect(function(Key, Serialized, Config)
			-- Remove existing
			DeregisterReplicant(Key)

			if Serialized ~= nil then
				local RegisteredReplicant = Replicant.FromSerialized(Serialized, Config)
				local Success, Replicator = PromiseChild(Replicators, Key, 20):Wait()
				if not Success or not Replicator then
					return
				end

				RegisteredReplicant:_SetContext(Context.new(RegisteredReplicant, {}, RegisteredReplicant.Config, true, Key))

				if IsInstanceGuid(Key) then
					-- Buffer instance keys and wait for corresponding instance to replicate
					CollectionBuffer[Key] = RegisteredReplicant
					InstanceGuidRegisteredSignal:Fire(RegisteredReplicant, Key)
				else
					-- For regular keys, register immediately
					Registry[Key] = RegisteredReplicant
					Replica.ReplicantRegistered:Fire(RegisteredReplicant, Key)
				end
			end
		end)
	end)
else
	local BaseReplicantEvent = ReplicatedStorage:WaitForChild("RemoteEvents", math.huge):WaitForChild("ReplicateBaseReplicant", math.huge)
	local GetGuidFunction = ReplicatedStorage:WaitForChild("RemoteFunctions", math.huge):WaitForChild("GetRegisteredGuid", math.huge)
	local SentInitialReplication = {}

	Replica.ReplicantRegistered:Connect(function(RegisteredReplicant, KeyRef)
		local Key
		if type(KeyRef) == "string" or type(KeyRef) == "number" then
			Key = KeyRef
		elseif typeof(KeyRef) == "Instance" then
			Key = InstanceGuidMap[KeyRef]
		end

		for _, Player in ipairs(Players:GetPlayers()) do
			if RegisteredReplicant:VisibleToClient(Player) and SentInitialReplication[Player] then
				BaseReplicantEvent:FireClient(Player, Key, RegisteredReplicant:Serialize(Key, Player), RegisteredReplicant.Config)
			end
		end
	end)

	Replica.ReplicantWillUnregister:Connect(function(RegisteredReplicant, KeyRef)
		local Key
		if type(KeyRef) == "string" or type(KeyRef) == "number" then
			Key = KeyRef
		elseif typeof(KeyRef) == "Instance" then
			Key = InstanceGuidMap[KeyRef]
		end

		for _, Player in ipairs(Players:GetPlayers()) do
			if RegisteredReplicant:VisibleToClient(Player) and SentInitialReplication[Player] then
				BaseReplicantEvent:FireClient(Player, Key, nil)
			end
		end
	end)

	local function SendInitReplicationToClient(Player)
		for Key, RegisteredReplicant in next, Registry do
			if RegisteredReplicant:VisibleToClient(Player) then
				BaseReplicantEvent:FireClient(Player, Key, RegisteredReplicant:Serialize(Key, Player), RegisteredReplicant.Config)
			end
		end

		SentInitialReplication[Player] = true
	end

	Players.PlayerAdded:Connect(SendInitReplicationToClient)
	for _, Player in ipairs(Players:GetPlayers()) do
		SendInitReplicationToClient(Player)
	end

	Players.PlayerRemoving:Connect(function(Player)
		SentInitialReplication[Player] = nil
	end)

	function GetGuidFunction.OnServerInvoke(_, Object)
		if typeof(Object) == "Instance" then
			return InstanceGuidMap[Object]
		end
	end

	-- Remove collection tags from cloned objects that are not registered
	CollectionService:GetInstanceAddedSignal(COLLECTION_TAG):Connect(function(Object)
		if not InstanceGuidMap[Object] then
			CollectionService:RemoveTag(Object, COLLECTION_TAG)
		end
	end)
end

return Replica
