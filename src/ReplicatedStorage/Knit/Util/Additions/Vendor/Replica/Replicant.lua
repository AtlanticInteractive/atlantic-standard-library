local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local DefaultConfig = require(script.Parent.DefaultConfig)
local Signal = require(script.Parent.Parent.Parent.Parent.Signal)
local StringRep = require(script.Parent.Parent.Parent.Utility.StringRep)
local Utility = require(script.Parent.Utility)

local Replicators = script.Parent.Replicators

local Replicant = {}
Replicant._Subclasses = nil
local Members = {}

function Members:GetConfig()
	return self.Config
end

function Members:SetConfig(NewConfig)
	self.Config = NewConfig
	self.ConfigInferred = false
	self:_SetContext(Context.new(self.Context.Base, self.Context.KeyPath, NewConfig))
end

function Members:_HookListeners()
	local Replicator = Replicators:FindFirstChild(self.Context.RegistryKey)
	if Replicator == nil then
		error("Replicator not found for key '" .. self.Context.RegistryKey .. "'; you should not receive errors like this")
	end

	self._Connections = {}
	if RunService:IsServer() then
		table.insert(self._Connections, Replicator.OnServerEvent:Connect(function(Client, Buffer)
			-- Fail silently if the client does not have the correct permissions
			if self:VisibleToClient(Client) and self.Config.ClientCanSet and not self:_MatchPredictions(Buffer) then
				self:_ApplyUpdate(Buffer)
			end
		end))
	else
		table.insert(self._Connections, Replicator.OnClientEvent:Connect(function(Buffer)
			if not self:_MatchPredictions(Buffer) then
				self:_ApplyUpdate(Buffer)
			end
		end))
	end
end

function Members:_SetContext(NewContext)
	self.Context = NewContext
	if not NewContext.Active then
		return
	end

	if self.ConfigInferred then
		self.Config = NewContext.Config
	elseif self.PartialConfig ~= nil then
		self.Config = Utility.OverrideDefaults(NewContext.Config, self.PartialConfig)
	end

	-- Recursively update config context in wrapped descendants
	for Index, Value in next, self.Wrapped do
		if type(Value) == "table" and rawget(Value, "_IsReplicant") == true then
			local ExtendedPath = Utility.Copy(NewContext.KeyPath)
			table.insert(ExtendedPath, Index)
			Value:_SetContext(NewContext.new(NewContext.Base, ExtendedPath, self.Config, NewContext.Active, NewContext.RegistryKey))
		end
	end

	-- Disconnect contextual replication listeners
	if self._Connections ~= nil then
		for _, Connection in ipairs(self._Connections) do
			Connection:Disconnect()
		end

		self._Connections = nil
	end

	-- Hook contextual replication listeners
	if NewContext.Base == self and NewContext.Active then
		self:_HookListeners()
	end
end

function Members:_InCollatingContext()
	if self.Collating then
		return true
	end

	local KeyPath = self.Context.KeyPath
	if #KeyPath > 0 then
		local Base = self.Context.Base
		for Index = 1, #KeyPath - 1 do
			Base = Base.Wrapped[KeyPath[Index]]
		end

		return Base:_InCollatingContext()
	end

	return false
end

function Members:_InLocalContext()
	if not self:CanReplicate() then
		return true
	end

	if self.ExplicitLocalContext then
		return true
	end

	local KeyPath = self.Context.KeyPath
	if #KeyPath > 0 then
		local Base = self.Context.Base
		for Index = 1, #KeyPath - 1 do
			Base = Base.Wrapped[KeyPath[Index]]
		end

		return Base:_InLocalContext()
	end

	return false
end

function Members:Get(Key)
	return self.Wrapped[Key]
end

function Members:Set(Key, Value)
	local IsLocal = self:_InLocalContext()

	self.WillUpdate:Fire(IsLocal)
	if self._Destroyed then
		error("Replicants should not be destroyed on WillUpdate")
	end

	local ValueWillUpdateSignal = self.ValueWillUpdateSignals[Key]
	if ValueWillUpdateSignal then
		ValueWillUpdateSignal:Fire(IsLocal)
	end

	self:_SetLocal(Key, Value)

	if self.Context.Active then
		-- Update context for nested replicants
		if type(Value) == "table" and rawget(Value, "_IsReplicant") then
			local ExtendedPath = Utility.Copy(self.Context.KeyPath)
			table.insert(ExtendedPath, Key)
			Value:_setContext(Context.new(self.Context.Base, ExtendedPath, self.Config, self.Context.Active, self.Context.RegistryKey))
		end

		-- Add to replication buffer
		if not IsLocal then
			self:_BufferRawUpdate(Key, Value)
			if not self:_InCollatingContext() then
				self:_FlushReplicationBuffer()
			end
		end
	end

	local ValueOnUpdateSignal = self.ValueOnUpdateSignals[Key]

	-- From this point on, the object could be destroyed
	self.OnUpdate:Fire(IsLocal)
	if ValueOnUpdateSignal then
		ValueOnUpdateSignal:Fire(IsLocal)
	end
end

function Members:Predict(Key, Value)
	if self:CanReplicate() then
		error("Predict can only be called on a side of the network that does not replicate")
	end

	if type(Value) == "table" and rawget(Value, "_IsReplicant") then
		error("Predict cannot be called for other Replicant values")
	end

	table.insert(self.PredictionBuffer, {Key, Value})
	self:Set(Key, Value)
end

function Members:_SetLocal()
	error("Abstract method _SetLocal() was not implemented; you should not see errors like this")
end

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
function Members:Serialize(AtKey, ForClient)
	if ForClient ~= nil and not self:VisibleToClient(ForClient) then
		return nil
	end

	local SymbolicValue = {}

	for Index, Value in next, self.Wrapped do
		if type(Value) == "table" and rawget(Value, "_IsReplicant") then
			table.insert(SymbolicValue, Value:Serialize(Index, ForClient))
		else
			table.insert(SymbolicValue, Utility.Serialize(Index, Value))
		end
	end

	return {AtKey, self._Class.SerialType, SymbolicValue, self._PreservationId}
end

function Members:Collate(Function)
	-- Call the callback normally if we're already collating
	if self:_InCollatingContext() then
		return Function()
	end

	-- Else spawn a collation thread and expect no yielding
	self.Collating = true

	task.spawn(function()
		local Success, Error = pcall(Function)
		self:_FlushReplicationBuffer()
		self.Collating = false
		assert(Success, Error)
	end)

	if self.Collating then
		error("Yielding is not allowed when calling Replicant:Collate()")
	end
end

function Members:_FlushReplicationBuffer()
	local Buffer = self.Context.Base.ReplicationBuffer
	self.Context.Base.ReplicationBuffer = {}

	if #Buffer == 0 then
		return
	end

	if not self.Context.Active or self.Context.RegistryKey == nil then
		error("Attempt to replicate from an unregistered Replicant; use Replica.Register first!")
	end

	local Replicator = Replicators:FindFirstChild(self.Context.RegistryKey)
	if Replicator == nil then
		error("Replicator not found for key '" .. self.Context.RegistryKey .. "'; you should not receive errors like this")
	end

	Replicant.RegisterSubclasses()

	if RunService:IsServer() then
		if self.Config.ServerCanSet then
			for _, Player in ipairs(Players:GetPlayers()) do
				local PartialBuffer = {}

				for _, Serialized in next, Buffer do
					local NestedSerialized = Serialized
					local NestedReplicant = self.Context.Base
					repeat
						local TopLevel = false
						local Key = NestedSerialized[1]
						local NewSerialType = NestedSerialized[2]
						local NewPartialSymbolicValue = NestedSerialized[3]

						if Replicant._Subclasses[NewSerialType] ~= nil then
							if #NewPartialSymbolicValue == 1 then
								NestedSerialized = NewPartialSymbolicValue[1]
								NestedReplicant = NestedReplicant.Wrapped[Key]
							else
								TopLevel = true
							end
						else
							TopLevel = true
						end
					until TopLevel or not NestedReplicant or not NestedSerialized

					if NestedReplicant then
						if NestedReplicant:VisibleToClient(Player) then
							table.insert(PartialBuffer, Serialized)
						end
					end
				end

				if #PartialBuffer > 0 then
					Replicator:FireClient(Player, PartialBuffer)
				end
			end
		else
			error("Replication is not allowed on the server for this configuration (Consider wrapping call in :Local())")
		end
	else
		if self.Config.ClientCanSet then
			Replicator:FireServer(Buffer)
		else
			error("Replication is not allowed on the client for this configuration (Consider wrapping call in :Local())")
		end
	end
end

function Members:_MatchPredictions(Buffer)
	if #self.PredictionBuffer == 0 then
		return false
	end

	Replicant.RegisterSubclasses()

	local ConsumedPrediction = false
	local PredictionBuffer = self.PredictionBuffer
	self.PredictionBuffer = {}
	for Index = 1, #PredictionBuffer do
		local NestedSerialized = Buffer[Index]
		if not NestedSerialized then
			if ConsumedPrediction then
				self.PredictionBuffer = {select(Index, table.unpack(PredictionBuffer))}
				return true
			end
		end

		local NestedReplicant = self.Context.Base
		repeat
			local TopLevel = false
			local Key = NestedSerialized[1]
			local NewSerialType = NestedSerialized[2]
			local NewPartialSymbolicValue = NestedSerialized[3]

			if Replicant._Subclasses[NewSerialType] ~= nil then
				if #NewPartialSymbolicValue == 1 then
					NestedSerialized = NewPartialSymbolicValue[1]
					NestedReplicant = NestedReplicant.Wrapped[Key]
				else
					TopLevel = true
				end
			else
				TopLevel = true
			end
		until TopLevel or not NestedReplicant or not NestedSerialized

		if NestedReplicant then
			local PredictedKey = PredictionBuffer[Index][1]
			local UpdatedKey = NestedSerialized[1]

			if PredictedKey == UpdatedKey then
				local PredictedValue = PredictionBuffer[Index][2]
				local ActualValue = Utility.Deserialize(NestedSerialized)

				if Utility.DeepCompare(PredictedValue, ActualValue) then
					ConsumedPrediction = true
				else
					return false
				end
			end
		end
	end

	return ConsumedPrediction
end

function Members:_ApplyUpdate(Buffer, DestroyList, RelocatedList, UpdateList)
	DestroyList = DestroyList or {}
	UpdateList = UpdateList or {}
	RelocatedList = RelocatedList or {}

	local IsLocal = self:_InLocalContext()

	self.WillUpdate:Fire(IsLocal)
	if #Buffer > 0 then
		UpdateList[self.OnUpdate] = true
	end

	local ExistingByPreservationId = {}
	for _, Existing in next, self.Wrapped do
		if type(Existing) == "table" and rawget(Existing, "_IsReplicant") and Existing._PreservationId ~= nil then
			ExistingByPreservationId[Existing._PreservationId] = Existing
		end
	end

	for _, Serialized in ipairs(Buffer) do
		local Key = Serialized[1]
		local NewPartialSymbolicValue = Serialized[3]
		local PreservationId = Serialized[4]

		if self.ValueWillUpdateSignals[Key] then
			self.ValueWillUpdateSignals[Key]:Fire(IsLocal)
		end

		if self.ValueOnUpdateSignals[Key] then
			UpdateList[self.ValueOnUpdateSignals[Key]] = true
		end

		local Existing = self.Wrapped[Key]
		if Existing == nil then
			self.Wrapped[Key] = Replicant.FromSerialized(Serialized, self.Config, self.Context)
		else
			local DisplacedExisting = PreservationId and ExistingByPreservationId[PreservationId]
			if DisplacedExisting then
				-- Re-add displaced object
				DestroyList[DisplacedExisting] = nil
				RelocatedList[DisplacedExisting] = true

				self.Wrapped[Key] = DisplacedExisting

				-- Update keypath context for displaced items
				if Existing ~= DisplacedExisting then
					local ExtendedPath = Utility.Copy(self.Context.KeyPath)
					table.insert(ExtendedPath, Key)
					DisplacedExisting:_SetContext(Context.new(self.Context.Base, ExtendedPath, self.Config, self.Context.Active, self.Context.RegistryKey))
				end

				-- Update buffered items
				if #NewPartialSymbolicValue > 0 then
					DisplacedExisting:_ApplyUpdate(NewPartialSymbolicValue, DestroyList, RelocatedList, UpdateList)
				end
			else
				if type(Existing) == "table" and rawget(Existing, "_IsReplicant") then
					if not RelocatedList[Existing] then
						DestroyList[Existing] = true
					end
				end

				local NewObject = Replicant.FromSerialized(Serialized, self.Config, self.Context)
				self.Wrapped[Key] = NewObject
				if type(NewObject) == "table" and rawget(Existing, "_IsReplicant") then
					if NewObject._PreservationId ~= nil then
						ExistingByPreservationId[NewObject._PreservationId] = NewObject
					end
				end
			end
		end
	end

	-- Destroy/update replicants after all actions in the buffer have been completed
	if self.Context.Base == self then
		for UpdateSignal in next, UpdateList do
			UpdateSignal:Fire(IsLocal)
		end

		for DestroyReplicant in next, DestroyList do
			DestroyReplicant:Destroy()
		end
	end
end

function Members:_BufferRawUpdate(WrappedKey, WrappedValue)
	if not self.Context.Active or self.Context.RegistryKey == nil or self:_InLocalContext() then
		return
	end

	local QualifiedBuffer = self.Context.Base.ReplicationBuffer

	local KeyIndex = 1
	local Key = self.Context.KeyPath[KeyIndex]
	local Base = self.Context.Base
	while Key ~= nil and Base ~= nil do
		local NextBase = Base.Wrapped[Key]
		if NextBase == nil then
			error("Invalid keypath '" .. table.concat(self.Context.KeyPath, ".") .. "'; you should not receive errors like this")
		end

		local NextBuffer = {}
		table.insert(QualifiedBuffer, {Key, NextBase._Class.SerialType, NextBuffer, NextBase._PreservationId})
		QualifiedBuffer = NextBuffer

		KeyIndex += 1
		Key = self.Context.KeyPath[KeyIndex]
		Base = NextBase
	end

	if type(WrappedValue) == "table" and rawget(WrappedValue, "_IsReplicant") then
		table.insert(QualifiedBuffer, WrappedValue:Serialize(WrappedKey))
	else
		table.insert(QualifiedBuffer, Utility.Serialize(WrappedKey, WrappedValue))
	end
end

function Members:Local(Function)
	-- If already in a local context, run the callback normally
	if self:_InLocalContext() then
		return Function()
	end

	-- Else create a new local context
	self.ExplicitLocalContext = true

	task.spawn(function()
		local Success, Error = pcall(Function)
		self.ExplicitLocalContext = false
		assert(Success, Error)
	end)

	if self.ExplicitLocalContext then
		error("Yielding is not allowed when calling Replicant:Local()")
	end
end

function Members:GetValueWillUpdateSignal(Key)
	local WillUpdateSignal = self.ValueWillUpdateSignals[Key]
	if WillUpdateSignal ~= nil then
		return WillUpdateSignal
	else
		WillUpdateSignal = Signal.new()
		self.ValueWillUpdateSignals[Key] = WillUpdateSignal
		return WillUpdateSignal
	end
end

function Members:GetValueOnUpdateSignal(Key)
	local OnUpdateSignal = self.ValueOnUpdateSignals[Key]
	if OnUpdateSignal ~= nil then
		return OnUpdateSignal
	else
		OnUpdateSignal = Signal.new()
		self.ValueOnUpdateSignals[Key] = OnUpdateSignal
		return OnUpdateSignal
	end
end

function Members:VisibleToClient(Client)
	if self.Config.SubscribeAll then
		for _, OtherClient in ipairs(self.Config.Blacklist) do
			if OtherClient == Client then
				return false
			end
		end

		return true
	else
		for _, OtherClient in ipairs(self.Config.Whitelist) do
			if OtherClient == Client then
				return true
			end
		end

		return false
	end
end

function Members:VisibleToAllClients()
	return self.Config.SubscribeAll and #self.Config.Blacklist == 0
end

function Members:CanReplicate()
	if RunService:IsServer() then
		return self.Config.ServerCanSet
	else
		return self.Config.ClientCanSet
	end
end

function Members:Inspect(MaxDepth, CurrentDepth, Key)
	MaxDepth = MaxDepth or math.huge
	CurrentDepth = CurrentDepth or 0
	if CurrentDepth > MaxDepth then
		return
	end

	local CurrentIndent = StringRep("	", CurrentDepth)
	local NextIndent = StringRep("	", CurrentDepth + 1)
	print(CurrentIndent .. (Key and (Key .. " = ") or "") .. self._Class.SerialType .. " {")
	if CurrentDepth > MaxDepth then
		return
	end

	for Index, Value in next, self.Wrapped do
		if type(Value) == "table" and rawget(Value, "_IsReplicant") == true then
			Value:Inspect(MaxDepth, CurrentDepth + 1, Index)
		else
			if type(Value) == "table" then
				Utility.Inspect(Value, MaxDepth, CurrentDepth + 1, Index)
			else
				local IndexString = tostring(Index)
				if type(Index) == "number" then
					IndexString = "[" .. IndexString .. "]"
				end

				local ValueString
				if type(Value) == "string" then
					ValueString = "'" .. tostring(Value) .. "'"
				else
					ValueString = tostring(Value)
				end

				print(NextIndent .. tostring(IndexString), "=", ValueString .. ",")
			end
		end
	end

	print(CurrentIndent .. "}")
end

function Members:MergeSerialized(Serialized)
	local Wrapped = Serialized[3]
	self:_ApplyUpdate(Wrapped)

	local QualifiedBuffer = self.Context.Base.ReplicationBuffer

	if self.Context.Active and not self:_InLocalContext() then
		local KeyIndex = 1
		local Key = self.Context.KeyPath[KeyIndex]
		local Base = self.Context.Base
		while Key ~= nil and Base ~= nil do
			local NextBase = Base.Wrapped[Key]
			if NextBase == nil then
				error("Invalid keypath '" .. table.concat(self.Context.KeyPath, ".") .. "'; you should not receive errors like this")
			end

			local NextBuffer = {}
			table.insert(QualifiedBuffer, {Key, NextBase._Class.SerialType, NextBuffer, NextBase._PreservationId})
			QualifiedBuffer = NextBuffer

			KeyIndex += 1
			Key = self.Context.KeyPath[KeyIndex]
			Base = NextBase
		end

		for _, SerializedKeyChange in next, Wrapped do
			table.insert(QualifiedBuffer, SerializedKeyChange)
		end

		if not self:_InCollatingContext() then
			self:_FlushReplicationBuffer()
		end
	end
end

function Members:Destroy()
	self:_SetContext(Context.new(self, {}, self.PartialConfig and Utility.OverrideDefaults(DefaultConfig, self.PartialConfig) or DefaultConfig, false, nil))

	self.WillUpdate:Destroy()
	self.OnUpdate:Destroy()

	self.WillUpdate = nil
	self.OnUpdate = nil

	if self._Connections ~= nil then
		for _, Connection in ipairs(self._Connections) do
			Connection:Disconnect()
		end

		self._Connections = nil
	end

	for _, UpdateSignal in next, self.ValueWillUpdateSignals do
		UpdateSignal:Destroy()
	end

	self.ValueWillUpdateSignals = nil
	for _, UpdateSignal in next, self.ValueOnUpdateSignals do
		UpdateSignal:Destroy()
	end

	self.ValueOnUpdateSignals = nil
	self._Destroyed = true
end

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
function Replicant.FromSerialized(Serialized, PartialConfig, NewContext)
	if type(Serialized) ~= "table" or type(Serialized[2]) ~= "string" then
		error("Bad argument #1 to Replicant.FromSerialized (value is not a serialized table)")
	end

	local SerialType, SymbolicValue, PreservationId = Serialized[2], Serialized[3], Serialized[4]
	if SerialType == "Replicant" then
		error("Unimplemented serial type for some replicant class; you should not receive errors like this")
	end

	-- Check subclasses
	Replicant.RegisterSubclasses()
	for SubclassSerialType, Class in next, Replicant._Subclasses do
		if SubclassSerialType == SerialType then
			local Object = Class.new(nil, PartialConfig, NewContext)
			Object._PreservationId = PreservationId
			Object:_ApplyUpdate(SymbolicValue)
			return Object
		end
	end

	-- Check primitives/rbx datatypes
	return Utility.Deserialize(Serialized)
end

function Replicant.RegisterSubclasses()
	if Replicant._Subclasses == nil then
		Replicant._Subclasses = {}
		for _, Child in ipairs(script.Parent.Replicants:GetChildren()) do
			if Child:IsA("ModuleScript") then
				local Subclass = require(Child)
				Replicant._Subclasses[Subclass.SerialType] = Subclass
			end
		end
	end
end

-- Should be implemented
Replicant.SerialType = "Replicant"

function Replicant:Constructor(PartialConfig, NewContext)
	local ConfigInferred = PartialConfig == nil
	if ConfigInferred then
		self.ConfigInferred = true
		self.Config = DefaultConfig
	else
		self.ConfigInferred = false
		self.Config = Utility.OverrideDefaults(DefaultConfig, PartialConfig)
		self.partialConfig = PartialConfig
	end

	self.Collating = false
	self.Context = NewContext or Context.new(self, {}, self.Config, false, nil)
	self.ExplicitLocalContext = false
	self.PredictionBuffer = {}
	self.ReplicationBuffer = {}
	self.Wrapped = {}
	self._IsReplicant = true
	self._Connections = nil
	self._Destroyed = false

	self.WillUpdate = Signal.new()
	self.OnUpdate = Signal.new()

	self.ValueWillUpdateSignals = {}
	self.ValueOnUpdateSignals = {}

	self._PreservationId = Utility.NextId()
end

-- OOP boilerplate
function Replicant.Extend()
	local SubclassStatics = setmetatable({}, {__index = Replicant})
	local SubclassMembers = setmetatable({}, {__index = Members})
	SubclassMembers._Class = SubclassStatics
	return SubclassStatics, SubclassMembers, Members
end

function Replicant:__tostring()
	return "Replicant"
end

return Replicant
