--# selene: allow(empty_if)
--- @typecheck mode: strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Debug = require(script.Parent.Utility.Debug)
local HeliumPractGlobalSystems = require(script.Parent.HeliumPractGlobalSystems)
local Symbols = require(script.Parent.Symbols)
local Types = require(script.Parent.Types)

local Heartbeat = RunService.Heartbeat

local Symbols_AttributeChangedSignals = Symbols.AttributeChangedSignals
local Symbols_Attributes = Symbols.Attributes
local Symbols_Children = Symbols.Children
local Symbols_CollectionServiceTags = Symbols.CollectionServiceTags
local Symbols_ElementKind = Symbols.ElementKind
local Symbols_ElementKinds_ContextConsumer = Symbols.ElementKinds.ContextConsumer
local Symbols_ElementKinds_ContextProvider = Symbols.ElementKinds.ContextProvider
local Symbols_ElementKinds_CreateInstance = Symbols.ElementKinds.CreateInstance
local Symbols_ElementKinds_Decorate = Symbols.ElementKinds.Decorate
local Symbols_ElementKinds_Index = Symbols.ElementKinds.Index
local Symbols_ElementKinds_LifecycleComponent = Symbols.ElementKinds.LifecycleComponent
local Symbols_ElementKinds_OnChild = Symbols.ElementKinds.OnChild
local Symbols_ElementKinds_Portal = Symbols.ElementKinds.Portal
local Symbols_ElementKinds_RenderComponent = Symbols.ElementKinds.RenderComponent
local Symbols_ElementKinds_SiblingCluster = Symbols.ElementKinds.SiblingCluster
local Symbols_ElementKinds_SignalComponent = Symbols.ElementKinds.SignalComponent
local Symbols_ElementKinds_Stamp = Symbols.ElementKinds.Stamp
local Symbols_ElementKinds_StateComponent = Symbols.ElementKinds.StateComponent
local Symbols_IsHeliumPractTree = Symbols.IsHeliumPractTree
local Symbols_None = Symbols.None
local Symbols_OnMountWithHost = Symbols.OnMountWithHost
local Symbols_OnUnmountWithHost = Symbols.OnUnmountWithHost
local Symbols_OnUpdateWithHost = Symbols.OnUpdateWithHost
local Symbols_PropertyChangedSignals = Symbols.PropertyChangedSignals

local APPLY_PROPS_ERROR = [[
Error applying props:
	%s
]]

local UPDATE_PROPS_ERROR = [[
Error updating props:
	%s
]]

local MISSING_PARENT_ERROR = [[
Attempt to mount index or decorate node on a nil parent host
]]

local DEFAULT_CREATED_CHILD_NAME = "HeliumPractTree"

local NOOP = function() end

-- Creates a closure-based reconciler which handles Pract systems globally

local function CreateReconciler(): Types.Reconciler
	local Reconciler: Types.Reconciler

	local MountVirtualNode: (Element: Types.Element | boolean | nil, HostContext: Types.HostContext) -> Types.VirtualNode?
	local MountVirtualTree: (Element: Types.Element, HostInstance: Instance?, HostKey: string?) -> Types.PractTree
	local UnmountVirtualNode: (VirtualNode: Types.VirtualNode) -> ()
	local UnmountVirtualTree
	local UpdateChildren: (VirtualNode: Types.VirtualNode, HostParent: Instance, ChildElements: Types.ChildrenArgument?) -> ()
	local UpdateVirtualNode: (VirtualNode: Types.VirtualNode, NewElement: Types.Element | boolean | nil) -> Types.VirtualNode?
	local UpdateVirtualTree

	local function ReplaceVirtualNode(VirtualNode: Types.VirtualNode, NewElement: Types.Element): Types.VirtualNode?
		local HostContext = VirtualNode._HostContext
		if not VirtualNode._WasUnmounted then
			UnmountVirtualNode(VirtualNode)
		end

		return MountVirtualNode(NewElement, HostContext)
	end

	local ApplyDecorationProperty: (VirtualNode: Types.VirtualNode, PropKey: string, NewValue: any, OldValue: any, EventMap: {[any]: RBXScriptConnection?}, Instance: Instance) -> ()

	do
		local SpecialApplyPropHandlers = {}
		SpecialApplyPropHandlers[Symbols_Children] = NOOP -- Handled in a separate pass
		SpecialApplyPropHandlers[Symbols_OnUnmountWithHost] = NOOP -- Handled in unmount
		SpecialApplyPropHandlers[Symbols_OnMountWithHost] = function(VirtualNode: Types.VirtualNode, NewValue, _, _, _)
			if not VirtualNode._CalledOnMountWithHost then
				VirtualNode._CalledOnMountWithHost = true
				if not NewValue then
					return
				end

				task.defer(function()
					if VirtualNode._WasUnmounted then
						return
					end

					local CurrentElement = VirtualNode._CurrentElement
					local Properties = CurrentElement.Properties
					local Function = Properties[Symbols_OnMountWithHost]
					local Object = VirtualNode._LastUpdateInstance
					if Function and Object then
						Function(Object, Properties, function(CleanupFunction: () -> ())
							if VirtualNode._WasUnmounted then
								return CleanupFunction()
							end

							local SpecialPropCleanupCallbacks = VirtualNode._SpecialPropCleanupCallbacks
							if not SpecialPropCleanupCallbacks then
								SpecialPropCleanupCallbacks = {}
								VirtualNode._SpecialPropCleanupCallbacks = SpecialPropCleanupCallbacks
							end

							table.insert(SpecialPropCleanupCallbacks, CleanupFunction)
						end)
					end
				end)
			end
		end

		SpecialApplyPropHandlers[Symbols_OnUpdateWithHost] = function(VirtualNode: Types.VirtualNode, NewValue, _, _, _)
			if not NewValue then
				return
			end

			if not VirtualNode._CollateDeferredUpdateCallback then
				VirtualNode._CollateDeferredUpdateCallback = true
				task.defer(function()
					VirtualNode._CollateDeferredUpdateCallback = nil
					if VirtualNode._WasUnmounted then
						return
					end

					local Properties = VirtualNode._CurrentElement.Properties
					local Function = Properties[Symbols_OnUpdateWithHost]
					local Object = VirtualNode._LastUpdateInstance
					if Function and Object then
						Function(Object, Properties)
					end
				end)
			end
		end

		SpecialApplyPropHandlers[Symbols_Attributes] = function(_, NewValue, OldValue, _, Object: Instance)
			if NewValue == OldValue then
				return
			end

			if OldValue == nil then
				for AttributeKey, AttributeValue in next, NewValue do
					if AttributeValue == Symbols_None then
						Object:SetAttribute(AttributeKey, nil)
					else
						Object:SetAttribute(AttributeKey, AttributeValue)
					end
				end
			elseif NewValue == nil then
			else
				for AttributeKey, AttributeValue in next, NewValue do
					if AttributeValue == Symbols_None then
						AttributeValue = nil
					end

					if OldValue[AttributeKey] ~= AttributeValue then
						Object:SetAttribute(AttributeKey, AttributeValue)
					end
				end

				for AttributeKey in next, NewValue do
					if NewValue[AttributeKey] == nil then
						Object:SetAttribute(AttributeKey, nil)
					end
				end
			end
		end

		do
			SpecialApplyPropHandlers[Symbols_CollectionServiceTags] = function(_, NewValue, OldValue, _, Object)
				if NewValue == OldValue then
					return
				end

				if OldValue == nil then
					for _, Value in ipairs(NewValue) do
						if not CollectionService:HasTag(Object, Value) then
							CollectionService:AddTag(Object, Value)
						end
					end
				elseif NewValue == nil then
					for _, Value in ipairs(OldValue) do
						if CollectionService:HasTag(Object, Value) then
							CollectionService:RemoveTag(Object, Value)
						end
					end
				else
					local OldTagsSet = {}
					for _, Tag in ipairs(OldValue) do
						OldTagsSet[Tag] = true
					end

					local NewTagsSet = {}
					for _, Tag in ipairs(NewValue) do
						NewTagsSet[Tag] = true
					end

					for _, Tag in ipairs(OldValue) do
						if not NewTagsSet[Tag] then
							CollectionService:RemoveTag(Object, Tag)
						end
					end

					for _, Tag in ipairs(NewValue) do
						if not OldTagsSet[Tag] then
							CollectionService:AddTag(Object, Tag)
						end
					end
				end
			end
		end

		do
			local function ApplyAttributeChangedSignal(VirtualNode: Types.VirtualNode, AttributeKey: string, NewValue: any, OldValue: any, EventMap: {[any]: RBXScriptConnection?}, Object: Instance)
				if OldValue == Symbols_None then
					OldValue = nil
				end

				if NewValue == Symbols_None then
					NewValue = nil
				end

				if NewValue == OldValue then
					return
				end

				local Signal = Object:GetAttributeChangedSignal(AttributeKey)
				if OldValue == nil then
					EventMap[AttributeKey] = Signal:Connect(function(...)
						local FunctionMap = VirtualNode._CurrentElement.Properties[Symbols_AttributeChangedSignals]
						if FunctionMap then
							local Function = FunctionMap[AttributeKey]
							if Function then
								if VirtualNode._DeferDecorationEvents then
									local Arguments = table.pack(...)
									task.defer(function()
										if VirtualNode._WasUnmounted then
											return
										end

										Function(Object, table.unpack(Arguments, 1, Arguments.n))
									end)
								else
									Function(Object, ...)
								end
							end
						end
					end)
				end
			end

			SpecialApplyPropHandlers[Symbols_AttributeChangedSignals] = function(VirtualNode: Types.VirtualNode, NewValue, OldValue, EventMap, Object: Instance)
				if NewValue == OldValue then
					return
				end

				local AttributesChangedEventMap
				if OldValue == nil then
					AttributesChangedEventMap = {}
					EventMap[Symbols_AttributeChangedSignals] = AttributesChangedEventMap :: any
					for AttributeKey, Function in next, NewValue do
						ApplyAttributeChangedSignal(VirtualNode, AttributeKey, Function, nil, AttributesChangedEventMap, Object)
					end
				elseif NewValue == nil then
					AttributesChangedEventMap = EventMap[Symbols_AttributeChangedSignals] :: any
					for AttributeKey, OldFunction in next, OldValue do
						ApplyAttributeChangedSignal(VirtualNode, AttributeKey, nil, OldFunction, AttributesChangedEventMap, Object)
					end
				else
					AttributesChangedEventMap = EventMap[Symbols_AttributeChangedSignals] :: any
					for AttributeKey, OldFunction in next, OldValue do
						ApplyAttributeChangedSignal(VirtualNode, AttributeKey, NewValue[AttributeKey], OldFunction, AttributesChangedEventMap, Object)
					end

					for AttributeKey, Function in next, NewValue do
						if not OldValue[AttributeKey] then
							ApplyAttributeChangedSignal(VirtualNode, AttributeKey, Function, nil, AttributesChangedEventMap, Object)
						end
					end
				end
			end
		end

		do
			local function ApplyPropChangedSignal(VirtualNode: Types.VirtualNode, PropertyKey: string, NewValue: any, OldValue: any, EventMap: {[any]: RBXScriptConnection?}, Object: Instance)
				if OldValue == Symbols_None then
					OldValue = nil
				end

				if NewValue == Symbols_None then
					NewValue = nil
				end

				local Signal = Object:GetPropertyChangedSignal(PropertyKey)
				if OldValue == nil then
					EventMap[PropertyKey] = Signal:Connect(function(...)
						local FunctionMap = VirtualNode._CurrentElement.Properties[Symbols_PropertyChangedSignals]
						if FunctionMap then
							local Function = FunctionMap[PropertyKey]
							if Function then
								if VirtualNode._DeferDecorationEvents then
									local Arguments = table.pack(...)
									task.defer(function()
										if VirtualNode._WasUnmounted then
											return
										end

										Function(Object, table.unpack(Arguments, 1, Arguments.n))
									end)
								else
									Function(Object, ...)
								end
							end
						end
					end)
				end
			end

			SpecialApplyPropHandlers[Symbols_PropertyChangedSignals] = function(VirtualNode: Types.VirtualNode, NewValue, OldValue, EventMap, Object: Instance)
				if OldValue == Symbols_None then
					OldValue = nil
				end

				if NewValue == Symbols_None then
					NewValue = nil
				end

				if NewValue == OldValue then
					return
				end

				local PropertiesChangedEventMap
				if OldValue == nil then
					PropertiesChangedEventMap = {}
					EventMap[Symbols_PropertyChangedSignals] = PropertiesChangedEventMap :: any
					for PropertyKey, Function in next, NewValue do
						ApplyPropChangedSignal(VirtualNode, PropertyKey, Function, nil, PropertiesChangedEventMap, Object)
					end
				elseif NewValue == nil then
					PropertiesChangedEventMap = EventMap[Symbols_PropertyChangedSignals] :: any
					for PropertyKey, OldFunction in next, OldValue do
						ApplyPropChangedSignal(VirtualNode, PropertyKey, nil, OldFunction, PropertiesChangedEventMap, Object)
					end
				else
					PropertiesChangedEventMap = EventMap[Symbols_PropertyChangedSignals] :: any
					for PropertyKey, OldFunction in next, OldValue do
						ApplyPropChangedSignal(VirtualNode, PropertyKey, NewValue[PropertyKey], OldFunction, PropertiesChangedEventMap, Object)
					end

					for PropertyKey, Function in next, NewValue do
						if not OldValue[PropertyKey] then
							ApplyPropChangedSignal(VirtualNode, PropertyKey, Function, nil, PropertiesChangedEventMap, Object)
						end
					end
				end
			end
		end

		function ApplyDecorationProperty(VirtualNode: Types.VirtualNode, PropertyKey: string, NewValue: any, OldValue: any, EventMap: {[any]: RBXScriptConnection?}, Object: Instance)
			if OldValue == Symbols_None then
				OldValue = nil
			end

			if NewValue == Symbols_None then
				NewValue = nil
			end

			local Function = SpecialApplyPropHandlers[PropertyKey]
			if Function then
				return Function(VirtualNode, NewValue, OldValue, EventMap, Object)
			end

			if NewValue == OldValue then
				return
			end

			if OldValue == nil then
				local DefaultValue = (Object :: any)[PropertyKey]
				if typeof(DefaultValue) == "RBXScriptSignal" then
					EventMap[PropertyKey] = DefaultValue:Connect(function(...)
						local PropertyFunction = VirtualNode._CurrentElement.Properties[PropertyKey]
						if PropertyFunction then
							if VirtualNode._DeferDecorationEvents then
								local Arguments = table.pack(...)
								task.defer(function()
									if VirtualNode._WasUnmounted then
										return
									end

									PropertyFunction(Object, table.unpack(Arguments, 1, Arguments.n))
								end)
							else
								PropertyFunction(Object, ...)
							end
						end
					end)
				else
					(Object :: any)[PropertyKey] = NewValue
				end
			elseif NewValue == nil then
				local Connection = EventMap[PropertyKey]
				if Connection then
					Connection:Disconnect()
				end

				-- Else we don't do anything to this property unless it's specified as None.
				-- Pract can leave footprints in property changes.
			else
				if EventMap[PropertyKey] then -- The new callback will automatically be located if the
					-- event fires.
					return
				end

				(Object :: any)[PropertyKey] = NewValue
			end
		end
	end

	local function UpdateDecorationProperties(VirtualNode: Types.VirtualNode, NewProperties: Types.PropertiesArgument, OldProperties: Types.PropertiesArgument, Object: Instance)
		local EventMap = VirtualNode._EventMap
		VirtualNode._DeferDecorationEvents = true
		VirtualNode._LastUpdateInstance = Object

		-- Apply props that were added or updated
		for PropertyKey, NewValue in next, NewProperties do
			local OldValue = OldProperties[PropertyKey]
			ApplyDecorationProperty(VirtualNode, PropertyKey, NewValue, OldValue, EventMap, Object)
		end

		-- Clean up props that were removed
		for PropertyKey, OldValue in next, OldProperties do
			local NewValue = NewProperties[PropertyKey]

			if NewValue == nil then
				ApplyDecorationProperty(VirtualNode, PropertyKey, nil, OldValue, EventMap, Object)
			end
		end

		VirtualNode._DeferDecorationEvents = false
	end

	local function MountDecorationProperties(VirtualNode: Types.VirtualNode, Properties: Types.PropertiesArgument, Object: Instance)
		VirtualNode._LastUpdateInstance = Object

		local EventMap = {}
		VirtualNode._EventMap = EventMap
		VirtualNode._DeferDecorationEvents = true

		for PropertyKey, InitialValue in next, Properties do
			ApplyDecorationProperty(VirtualNode, PropertyKey, InitialValue, nil, EventMap, Object)
		end

		VirtualNode._DeferDecorationEvents = false
	end

	local function UnmountDecorationProperties(VirtualNode: Types.VirtualNode, WillDestroy: boolean)
		local LastProperties = VirtualNode._CurrentElement.Properties
		local EventMap = VirtualNode._EventMap
		if EventMap then
			VirtualNode._EventMap = nil

			if not WillDestroy then
				local EventMaps = {EventMap}
				local AttributesChangedEvents = EventMap[Symbols_AttributeChangedSignals]
				if AttributesChangedEvents then
					EventMap[Symbols_AttributeChangedSignals] = nil
					table.insert(EventMaps, AttributesChangedEvents)
				end

				local PropertiesChangedEvents = EventMap[Symbols_PropertyChangedSignals]
				if PropertiesChangedEvents then
					EventMap[Symbols_PropertyChangedSignals] = nil
					table.insert(EventMaps, PropertiesChangedEvents)
				end

				for _, Map in ipairs(EventMaps) do
					for _, Connection in next, Map do
						Connection:Disconnect()
					end
				end
			end
		end

		local ToCallWithHostInstance = {}
		local SpecialPropCleanupCallbacks = VirtualNode._SpecialPropCleanupCallbacks
		if SpecialPropCleanupCallbacks then
			VirtualNode._SpecialPropCleanupCallbacks = nil
			for _, SpecialPropCleanupCallback in ipairs(SpecialPropCleanupCallbacks) do
				table.insert(ToCallWithHostInstance, SpecialPropCleanupCallback)
			end
		end

		local LastUpdateInstance = VirtualNode._LastUpdateInstance
		if LastUpdateInstance then
			if not WillDestroy then
				local LastTags = LastProperties[Symbols_CollectionServiceTags]
				if LastTags then
					for _, LastTag in ipairs(LastTags) do
						CollectionService:RemoveTag(LastUpdateInstance, LastTag)
					end
				end

				local LastAttributes = LastProperties[Symbols_Attributes]
				if LastAttributes then
					for AttributeName in next, LastAttributes do
						LastUpdateInstance:SetAttribute(AttributeName, nil)
					end
				end
			end

			local LastElement = VirtualNode._CurrentElement
			local OnUnmountFunction = LastElement.Properties[Symbols_OnUnmountWithHost]
			if OnUnmountFunction then
				table.insert(ToCallWithHostInstance, OnUnmountFunction)
			end

			for _, ToCall in ipairs(ToCallWithHostInstance) do
				task.defer(ToCall, LastUpdateInstance)
			end
		end
	end

	local function GetIndexedChildFromHost(HostContext: Types.HostContext): Instance?
		local Object
		local Parent = HostContext.Instance
		if Parent then
			local ChildKey = HostContext.ChildKey
			if ChildKey then
				Object = Parent:FindFirstChild(ChildKey)
			else
				Object = Parent
			end
		else
			Debug.Error(MISSING_PARENT_ERROR)
		end

		return Object
	end

	local function CreateHost(Object: Instance?, Key: string?, Providers: {Types.ContextProvider}): Types.HostContext
		return {
			ChildKey = Key;
			Instance = Object;

			-- List (from root to last provider) of ancestor context providers in this tree
			Providers = Providers;
		} :: Types.HostContext
	end

	local function CreateVirtualNode(Element: Types.Element, Host: Types.HostContext, _ContextProviders: {Types.ContextProvider}?): Types.VirtualNode
		return {
			--[Symbols_IsPractVirtualNode] = true,
			_CurrentElement = Element;
			_HostContext = Host;
			_WasUnmounted = false;
		}
	end

	local MountNodeOnChild, UnmountOnChildNode

	do
		function UnmountOnChildNode(Node: Types.VirtualNode)
			if Node._Resolved then
				local ResolvedNode = Node._ResolvedNode
				if ResolvedNode then
					UnmountVirtualNode(ResolvedNode)
				end
			end
		end

		function MountNodeOnChild(VirtualNode: Types.VirtualNode)
			local HostContext = VirtualNode._HostContext
			local HostInstance = HostContext.Instance :: Instance
			local HostKey = HostContext.ChildKey :: string

			local OnChildElement = {
				[Symbols_ElementKind] = Symbols_ElementKinds_OnChild;
				WrappedElement = VirtualNode._CurrentElement;
			}

			VirtualNode._CurrentElement = OnChildElement
			VirtualNode._Resolved = false

			task.defer(function()
				local TriesAttempted = 0
				while true do -- repeat until false
					TriesAttempted += 1
					local Child = HostInstance:WaitForChild(HostKey, HeliumPractGlobalSystems.ON_CHILD_TIMEOUT_INTERVAL)
					if VirtualNode._WasUnmounted then
						return
					end

					if Child then
						VirtualNode._Resolved = true
						VirtualNode._ResolvedNode = MountVirtualNode(VirtualNode._CurrentElement.WrappedElement, HostContext)
						return
					elseif TriesAttempted == 1 then
						Debug.Warn("Attempt to mount decorate or index element on child \"" .. HostKey .. "\" of %q timed out. Perhaps the child key was named incorrectly?", HostInstance)
					end
				end
			end)
		end
	end

	do
		local UpdateByElementKind = {}
		-- OnChild elements should never be created by the user; new node replacements for
		-- unresolved onChild nodes are handled elsewhere as an exceptional case instead.
		UpdateByElementKind[Symbols_ElementKinds_Decorate] = function(VirtualNode: Types.VirtualNode, NewElement)
			local Object = VirtualNode._Instance
			if not Object then
				Object = GetIndexedChildFromHost(VirtualNode._HostContext)
			end

			if Object then
				local Success, Error = pcall(UpdateDecorationProperties, VirtualNode, NewElement.Properties, VirtualNode._CurrentElement.Properties, Object)
				if not Success then
					Debug.Error(string.format(UPDATE_PROPS_ERROR, Error)) --, 0)
				end

				UpdateChildren(VirtualNode, Object, NewElement.Properties[Symbols_Children])
			end

			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_Index] = function(VirtualNode: Types.VirtualNode, NewElement)
			local Object = VirtualNode._Instance
			if not Object then
				Object = GetIndexedChildFromHost(VirtualNode._HostContext)
			end

			if Object then
				UpdateChildren(VirtualNode, Object, NewElement.Children)
			end

			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_Stamp] = function(VirtualNode: Types.VirtualNode, NewElement)
			local Success, Error = pcall(UpdateDecorationProperties, VirtualNode, NewElement.Properties, VirtualNode._CurrentElement.Properties, VirtualNode._Instance)
			if not Success then
				Debug.Error(string.format(UPDATE_PROPS_ERROR, Error)) -- , 0)
			end

			UpdateChildren(VirtualNode, VirtualNode._Instance, NewElement.Properties[Symbols_Children])
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_CreateInstance] = function(VirtualNode: Types.VirtualNode, NewElement)
			local Success, Error = pcall(UpdateDecorationProperties, VirtualNode, NewElement.Properties, VirtualNode._CurrentElement.Properties, VirtualNode._Instance)
			if not Success then
				Debug.Error(string.format(UPDATE_PROPS_ERROR, Error)) -- , 0)
			end

			UpdateChildren(VirtualNode, VirtualNode._Instance, NewElement.Properties[Symbols_Children])
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_Portal] = function(VirtualNode: Types.VirtualNode, NewElement)
			local Element = VirtualNode._CurrentElement
			if Element.HostParent ~= NewElement.HostParent then
				return ReplaceVirtualNode(VirtualNode, NewElement)
			end

			UpdateChildren(VirtualNode, NewElement.HostParent, NewElement.Children)
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_RenderComponent] = function(VirtualNode: Types.VirtualNode, NewElement)
			local SaveElement = VirtualNode._CurrentElement
			if SaveElement.Component ~= NewElement.Component then
				return ReplaceVirtualNode(VirtualNode, NewElement)
			end

			VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, NewElement.Component(NewElement.Properties))
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_LifecycleComponent] = function(VirtualNode: Types.VirtualNode, NewElement)
			-- We don't care if our makeLifecycleClosure changes in this case, since the component
			-- returned from withLifecycle should be unique.

			local Closure = VirtualNode._LifecycleClosure :: Types.Lifecycle
			local SaveElement = VirtualNode._CurrentElement

			local ShouldUpdate = Closure.ShouldUpdate
			if ShouldUpdate then
				if not ShouldUpdate(NewElement.Properties, SaveElement.Properties) then
					return VirtualNode
				end
			end

			local WillUpdate = Closure.WillUpdate
			if WillUpdate then
				task.spawn(WillUpdate, NewElement.Properties, SaveElement.Properties)
			end

			-- Apply render update
			VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, Closure.Render(NewElement.Properties))

			local DidUpdate = Closure.DidUpdate
			if DidUpdate then
				if not VirtualNode._CollateDeferredUpdateCallback then
					VirtualNode._CollateDeferredUpdateCallback = true
					task.defer(function()
						VirtualNode._CollateDeferredUpdateCallback = nil
						if VirtualNode._WasUnmounted then
							return
						end

						local Function = VirtualNode._LifecycleClosure.DidUpdate
						local LastProperties = VirtualNode._CurrentElement.Properties
						if Function and LastProperties then
							Function(LastProperties)
						end
					end)
				end
			end

			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_StateComponent] = function(VirtualNode: Types.VirtualNode, NewElement)
			VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, VirtualNode._RenderClosure(NewElement.Properties))
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_SignalComponent] = function(VirtualNode: Types.VirtualNode, NewElement)
			if VirtualNode._CurrentElement.Signal ~= NewElement.Signal then
				return ReplaceVirtualNode(VirtualNode, NewElement)
			end

			VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, NewElement.Render(NewElement.Properties))
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_ContextProvider] = function(VirtualNode: Types.VirtualNode, NewElement)
			VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, VirtualNode._RenderClosure(NewElement.Properties))
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_ContextConsumer] = function(VirtualNode: Types.VirtualNode, NewElement)
			VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, VirtualNode._RenderClosure(NewElement.Properties))
			return VirtualNode
		end

		UpdateByElementKind[Symbols_ElementKinds_SiblingCluster] = function(VirtualNode: Types.VirtualNode, NewElement)
			local Siblings = VirtualNode._Siblings
			local Elements = NewElement.Elements
			local NextSiblings = table.create(#Elements)
			for Index, Sibling in ipairs(Siblings) do
				table.insert(NextSiblings, UpdateVirtualNode(Sibling, Elements[Index]))
			end

			for Index = #Siblings + 1, #Elements do
				table.insert(NextSiblings, MountVirtualNode(Elements[Index], VirtualNode._HostContext))
			end

			VirtualNode._Siblings = NextSiblings
			return VirtualNode
		end

		setmetatable(UpdateByElementKind, {
			__index = function(_, ElementKind)
				Debug.Error("Attempt to update VirtualNode with unhandled ElementKind %q", ElementKind)
			end;
		})

		function UpdateVirtualNode(VirtualNode: Types.VirtualNode, NewElement: Types.Element | boolean | nil): Types.VirtualNode?
			local CurrentElement = VirtualNode._CurrentElement
			if CurrentElement == NewElement then
				return VirtualNode
			end

			if NewElement == nil or type(NewElement) == "boolean" then
				UnmountVirtualNode(VirtualNode)
				return nil :: any
			end

			local Kind = (NewElement :: any)[Symbols_ElementKind]
			if CurrentElement[Symbols_ElementKind] == Kind then
				local NextNode = UpdateByElementKind[Kind](VirtualNode, NewElement :: any)
				if NextNode then
					NextNode._CurrentElement = NewElement :: any
				end

				return NextNode
			else
				if CurrentElement[Symbols_ElementKind] == Symbols_ElementKinds_OnChild then
					if VirtualNode._Resolved then
						-- Place in child node if it was latently resolved and mounted
						local ResolvedNode = VirtualNode._ResolvedNode :: Types.VirtualNode
						if ResolvedNode then
							return UpdateVirtualNode(ResolvedNode, NewElement)
						end

						return ResolvedNode
					else
						-- Compare the elementkind of our wrapped element, and simply swap it out
						-- if it has not changed.
						if VirtualNode._CurrentElement.WrappedElement[Symbols_ElementKind] == Kind then
							VirtualNode._CurrentElement.WrappedElement = NewElement
							return VirtualNode
						end
					end
				end

				-- Else, unmount this node and replace it with a new node.
				return ReplaceVirtualNode(VirtualNode, NewElement :: any)
			end
		end
	end

	local function MountChildren(VirtualNode: Types.VirtualNode)
		VirtualNode._UpdateChildrenCount = 0
		VirtualNode._Children = {}
	end

	local function UnmountChildren(VirtualNode: Types.VirtualNode)
		for _, ChildNode in next, VirtualNode._Children do
			UnmountVirtualNode(ChildNode)
		end
	end

	function UpdateChildren(VirtualNode: Types.VirtualNode, HostParent: Instance, PossibleNewChildElements: Types.ChildrenArgument?)
		local NewChildElements: Types.ChildrenArgument = PossibleNewChildElements or {}

		local SaveUpdateChildrenCount = VirtualNode._UpdateChildrenCount + 1
		VirtualNode._UpdateChildrenCount = SaveUpdateChildrenCount

		local ChildrenMap = VirtualNode._Children

		-- Changed or removed children
		local KeysToRemove = {}
		for ChildKey, ChildNode in next, ChildrenMap do
			local NewElement = NewChildElements[ChildKey]
			local NewNode = UpdateVirtualNode(ChildNode, NewElement)

			-- If updating this node has caused a component higher up the tree to re-render
			-- and updateChildren to be re-entered for this virtualNode then
			-- this result is invalid and needs to be disgarded.
			if VirtualNode._UpdateChildrenCount ~= SaveUpdateChildrenCount then
				if NewNode and NewNode ~= ChildrenMap[ChildKey] then
					UnmountVirtualNode(NewNode)
				end

				return
			end

			if NewNode ~= nil then
				ChildrenMap[ChildKey] = NewNode
			else
				table.insert(KeysToRemove, ChildKey)
			end
		end

		for _, ChildKey in ipairs(KeysToRemove) do
			ChildrenMap[ChildKey] = nil
		end

		-- Added children
		for ChildKey, NewElement in next, NewChildElements do
			if ChildrenMap[ChildKey] == nil then
				local ChildNode = MountVirtualNode(NewElement, CreateHost(HostParent, tostring(ChildKey), VirtualNode._HostContext.Providers))

				-- If updating this node has caused a component higher up the tree to re-render
				-- and updateChildren to be re-entered for this virtualNode then
				-- this result is invalid and needs to be discarded.
				if VirtualNode._UpdateChildrenCount ~= SaveUpdateChildrenCount then
					if ChildNode then
						UnmountVirtualNode(ChildNode)
					end

					return
				end

				-- mountVirtualNode can return nil if the element is a boolean
				if ChildNode ~= nil then
					VirtualNode._Children[ChildKey] = ChildNode
				end
			end
		end
	end

	do
		local MountByElementKind = {}

		MountByElementKind[Symbols_ElementKinds_Stamp] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			local Properties = Element.Properties
			local HostContext = VirtualNode._HostContext

			local Object = Element.Template:Clone()
			Object.Name = HostContext.ChildKey or DEFAULT_CREATED_CHILD_NAME

			local Success, Error = pcall(MountDecorationProperties, VirtualNode, Properties, Object)
			if not Success then
				Debug.Error(string.format(APPLY_PROPS_ERROR, Error)) --, 0)
			end

			MountChildren(VirtualNode)
			UpdateChildren(VirtualNode, Object, Properties[Symbols_Children])

			Object.Parent = HostContext.Instance
			VirtualNode._Instance = Object
		end

		MountByElementKind[Symbols_ElementKinds_CreateInstance] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			local Properties = Element.Properties
			local Object = Instance.new(Element.ClassName)
			local HostContext = VirtualNode._HostContext
			Object.Name = HostContext.ChildKey or DEFAULT_CREATED_CHILD_NAME

			local Success, Error = pcall(MountDecorationProperties, VirtualNode, Properties, Object)
			if not Success then
				Debug.Error(string.format(APPLY_PROPS_ERROR, Error)) --, 0)
			end

			MountChildren(VirtualNode)
			UpdateChildren(VirtualNode, Object, Properties[Symbols_Children])

			Object.Parent = HostContext.Instance
			VirtualNode._Instance = Object
		end

		MountByElementKind[Symbols_ElementKinds_Index] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			local Object = VirtualNode._Instance
			if not Object then
				Object = GetIndexedChildFromHost(VirtualNode._HostContext)
			end

			if Object then
				MountChildren(VirtualNode)
				UpdateChildren(VirtualNode, Object, Element.Children)
			else
				MountNodeOnChild(VirtualNode) -- hostContext.instance and hostContext.childKey
				-- must exist in this case!
			end
		end

		MountByElementKind[Symbols_ElementKinds_Decorate] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			local Properties = Element.Properties
			local Object = VirtualNode._Instance
			if not Object then
				Object = GetIndexedChildFromHost(VirtualNode._HostContext)
			end

			if Object then
				local Success, Error = pcall(MountDecorationProperties, VirtualNode, Properties, Object)
				if not Success then
					Debug.Error(string.format(APPLY_PROPS_ERROR, Error)) --, 0)
				end

				MountChildren(VirtualNode)
				UpdateChildren(VirtualNode, Object, Properties[Symbols_Children])
			else
				MountNodeOnChild(VirtualNode) -- hostContext.instance and hostContext.childKey
				-- must exist in this case!
			end
		end

		MountByElementKind[Symbols_ElementKinds_Portal] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			MountChildren(VirtualNode)
			UpdateChildren(VirtualNode, Element.HostParent, Element.Children)
		end

		MountByElementKind[Symbols_ElementKinds_RenderComponent] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			VirtualNode._Child = MountVirtualNode(Element.Component(Element.Properties), VirtualNode._HostContext)
		end

		MountByElementKind[Symbols_ElementKinds_LifecycleComponent] = function(VirtualNode: Types.VirtualNode)
			local LastDeferredUpdateHeartbeatCount = -1
			local function ForceUpdate()
				if not VirtualNode._Child then
					return
				end

				if not VirtualNode._CollateDeferredForcedUpdates then
					VirtualNode._CollateDeferredForcedUpdates = true
					task.defer(function()
						-- Allow a maximum of one update per frame (during Heartbeat)
						-- with forceUpdate calls in this closure.
						if LastDeferredUpdateHeartbeatCount == HeliumPractGlobalSystems.HeartbeatFrameCount then
							Heartbeat:Wait()
						end

						LastDeferredUpdateHeartbeatCount = HeliumPractGlobalSystems.HeartbeatFrameCount

						-- Resume
						VirtualNode._CollateDeferredForcedUpdates = nil
						if VirtualNode._WasUnmounted then
							return
						end

						local SaveElement = VirtualNode._CurrentElement
						VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, VirtualNode._LifecycleClosure.Render(SaveElement.Properties))
					end)
				end
			end

			local Element = VirtualNode._CurrentElement
			local Closure = Element.MakeLifecycleClosure(ForceUpdate) :: Types.Lifecycle

			local Initialize = Closure.Initialize
			if Initialize then
				Initialize(Element.Properties)
			end

			VirtualNode._LifecycleClosure = Closure
			VirtualNode._Child = MountVirtualNode(Closure.Render(Element.Properties), VirtualNode._HostContext)

			local DidMount = Closure.DidMount
			if DidMount then
				task.defer(DidMount, Element.Properties)
			end
		end

		MountByElementKind[Symbols_ElementKinds_StateComponent] = function(VirtualNode: Types.VirtualNode)
			local CurrentState = nil :: any
			local StateListenerSet = {}
			local LastDeferredChangeHeartbeatCount = -1
			local function GetState()
				return CurrentState
			end

			local function SetState(NextState)
				-- If we aren't mounted, set currentState without any side effects
				if not VirtualNode._Child then
					CurrentState = NextState
					return
				end

				if VirtualNode._WasUnmounted then
					CurrentState = NextState
					return
				end

				CurrentState = NextState
				local Element = VirtualNode._CurrentElement
				if Element.Deferred then
					if not VirtualNode._CollateDeferredState then
						VirtualNode._CollateDeferredState = true
						task.defer(function()
							-- Allow a maximum of one update per frame (during Heartbeat)
							-- with this state closure.
							if LastDeferredChangeHeartbeatCount == HeliumPractGlobalSystems.HeartbeatFrameCount then
								Heartbeat:Wait()
							end

							LastDeferredChangeHeartbeatCount = HeliumPractGlobalSystems.HeartbeatFrameCount

							-- Resume
							VirtualNode._CollateDeferredState = nil

							local FunctionsToCall = {}
							for Function in next, StateListenerSet do
								table.insert(FunctionsToCall, Function)
							end

							-- Call external listeners before updating
							for _, Function in ipairs(FunctionsToCall) do
								task.spawn(function()
									-- Abort if side effects cause the component to unmount
									if VirtualNode._WasUnmounted then
										return
									end

									Function()
								end)
							end

							-- Abort if side effects cause the component to unmount
							if VirtualNode._WasUnmounted then
								return
							end

							VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, VirtualNode._RenderClosure(VirtualNode._CurrentElement.Properties))
						end)
					end
				else
					local FunctionsToCall = {}
					for Function in next, StateListenerSet do
						table.insert(FunctionsToCall, Function)
					end

					-- Call external listeners before updating
					for _, Function in ipairs(FunctionsToCall) do
						task.spawn(function()
							-- Abort if side effects cause the component to unmount
							if VirtualNode._WasUnmounted then
								return
							end

							Function()
						end)
					end

					-- Abort if side effects cause the component to unmount
					if VirtualNode._WasUnmounted then
						return
					end

					VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, VirtualNode._RenderClosure(Element.Properties))
				end
			end

			local function SubscribeState(Function: () -> ())
				if VirtualNode._WasUnmounted then
					return NOOP
				end

				StateListenerSet[Function] = true
				return function()
					StateListenerSet[Function] = nil
				end
			end

			local Element = VirtualNode._CurrentElement
			local Closure = Element.MakeStateClosure(GetState, SetState, SubscribeState)

			VirtualNode._Child = MountVirtualNode(Closure(Element.Properties), VirtualNode._HostContext)
			VirtualNode._RenderClosure = Closure
		end

		MountByElementKind[Symbols_ElementKinds_SignalComponent] = function(VirtualNode: Types.VirtualNode)
			local Element = VirtualNode._CurrentElement
			VirtualNode._Child = MountVirtualNode(Element.Render(Element.Properties), VirtualNode._HostContext)
			VirtualNode._Connection = Element.Signal:Connect(function()
				if VirtualNode._WasUnmounted then
					return
				end

				local CurrentElement = VirtualNode._CurrentElement
				VirtualNode._Child = UpdateVirtualNode(VirtualNode._Child, CurrentElement.Render(CurrentElement.Properties))
			end)
		end

		MountByElementKind[Symbols_ElementKinds_ContextProvider] = function(VirtualNode: Types.VirtualNode)
			local HostContext = VirtualNode._HostContext

			local ProvidedObjectsMap = {}
			local Provider: Types.ContextProvider = {
				Find = function(Key: string)
					return ProvidedObjectsMap[Key]
				end;

				Provide = function(Key, Object)
					ProvidedObjectsMap[Key] = Object
				end;

				Unprovide = function(Key)
					ProvidedObjectsMap[Key] = nil
				end;
			}

			local LastProviderChain = HostContext.Providers
			local Length = #LastProviderChain
			local NextProviderChain = table.move(LastProviderChain, 1, Length, 1, table.create(Length + 1))
			table.insert(NextProviderChain, Provider)

			local Element = VirtualNode._CurrentElement
			local Closure = Element.MakeClosure(function(Key: string, Object: any)
				Provider.Provide(Key, Object)
				return function()
					Provider.Unprovide(Key)
				end
			end)

			VirtualNode._Child = MountVirtualNode(Closure(Element.Properties), CreateHost(HostContext.Instance, HostContext.ChildKey, NextProviderChain))
			VirtualNode._RenderClosure = Closure
		end

		MountByElementKind[Symbols_ElementKinds_ContextConsumer] = function(VirtualNode: Types.VirtualNode)
			local HostContext = VirtualNode._HostContext
			local ProviderChain = HostContext.Providers

			local Element = VirtualNode._CurrentElement
			local Closure = Element.MakeClosure(function(Key: string): any?
				for Index = #ProviderChain, 1, -1 do
					local Object = ProviderChain[Index].Find(Key)
					if Object then
						return Object
					end
				end

				return nil
			end)

			VirtualNode._Child = MountVirtualNode(Closure(Element.Properties), HostContext)
			VirtualNode._RenderClosure = Closure
		end

		MountByElementKind[Symbols_ElementKinds_SiblingCluster] = function(VirtualNode: Types.VirtualNode)
			local Elements = VirtualNode._CurrentElement.Elements
			local Siblings = table.create(#Elements)
			for _, Element in ipairs(Elements) do
				table.insert(Siblings, MountVirtualNode(Element, VirtualNode._HostContext))
			end

			VirtualNode._Siblings = Siblings
			return VirtualNode
		end

		setmetatable(MountByElementKind, {
			__index = function(_, ElementKind)
				Debug.Error("Attempt to mount invalid VirtualNode of ElementKind %q", ElementKind)
			end;
		})

		function MountVirtualNode(Element: Types.Element | boolean | nil, HostContext: Types.HostContext): Types.VirtualNode?
			if Element == nil or type(Element) == "boolean" then
				return nil :: any
			end

			local VirtualNode = CreateVirtualNode(Element :: any, HostContext)
			MountByElementKind[(Element :: Types.Element)[Symbols_ElementKind]](VirtualNode)
			return VirtualNode
		end
	end

	do
		local UnmountByElementKind = {}
		local function UnmountChild(VirtualNode: Types.VirtualNode)
			UnmountVirtualNode(VirtualNode._Child)
		end

		local function UnmountDestroy(VirtualNode: Types.VirtualNode)
			UnmountDecorationProperties(VirtualNode, true)
			UnmountChildren(VirtualNode)
			VirtualNode._Instance:Destroy()
		end

		UnmountByElementKind[Symbols_ElementKinds_OnChild] = UnmountOnChildNode
		UnmountByElementKind[Symbols_ElementKinds_Decorate] = function(VirtualNode: Types.VirtualNode)
			UnmountDecorationProperties(VirtualNode, false)
			UnmountChildren(VirtualNode)
		end

		UnmountByElementKind[Symbols_ElementKinds_CreateInstance] = UnmountDestroy
		UnmountByElementKind[Symbols_ElementKinds_Stamp] = UnmountDestroy
		UnmountByElementKind[Symbols_ElementKinds_Portal] = UnmountChildren
		UnmountByElementKind[Symbols_ElementKinds_RenderComponent] = UnmountChild
		UnmountByElementKind[Symbols_ElementKinds_Index] = UnmountChildren

		UnmountByElementKind[Symbols_ElementKinds_LifecycleComponent] = function(VirtualNode: Types.VirtualNode)
			local SaveElement = VirtualNode._CurrentElement
			local Closure = VirtualNode._LifecycleClosure :: Types.Lifecycle

			local WillUnmount = Closure.WillUnmount
			if WillUnmount then
				WillUnmount(SaveElement.Properties)
			end

			UnmountVirtualNode(VirtualNode._Child)
		end

		UnmountByElementKind[Symbols_ElementKinds_StateComponent] = UnmountChild
		UnmountByElementKind[Symbols_ElementKinds_SignalComponent] = function(VirtualNode: Types.VirtualNode)
			VirtualNode._Connection:Disconnect()
			UnmountVirtualNode(VirtualNode._Child)
		end

		UnmountByElementKind[Symbols_ElementKinds_ContextProvider] = UnmountChild
		UnmountByElementKind[Symbols_ElementKinds_ContextConsumer] = UnmountChild
		UnmountByElementKind[Symbols_ElementKinds_SiblingCluster] = function(VirtualNode: Types.VirtualNode)
			for _, Sibling in ipairs(VirtualNode._Siblings) do
				UnmountVirtualNode(Sibling)
			end
		end

		setmetatable(UnmountByElementKind, {
			__index = function(_, ElementKind)
				Debug.Error("Attempt to unmount VirtualNode with unhandled ElementKind %q", ElementKind)
			end;
		})

		function UnmountVirtualNode(VirtualNode: Types.VirtualNode)
			VirtualNode._WasUnmounted = true
			UnmountByElementKind[(VirtualNode._CurrentElement :: Types.Element)[Symbols_ElementKind]](VirtualNode)
		end
	end

	function UpdateVirtualTree(Tree: Types.PractTree, NewElement: Types.Element)
		local RootNode = Tree._RootNode
		if RootNode then
			Tree._RootNode = UpdateVirtualNode(RootNode, NewElement)
		end
	end

	function MountVirtualTree(Element: Types.Element, HostInstance: Instance?, HostChildKey: string?): Types.PractTree
		if type(Element) ~= "table" or Element[Symbols_ElementKind] == nil then
			Debug.Error("invalid argument #1 to HeliumPract.Mount (HeliumPract.Element expected, got %q)", Element)
		end

		local Tree = {
			[Symbols_IsHeliumPractTree] = true;
			_Mounted = true;
			_RootNode = (nil :: any) :: Types.VirtualNode?;
		}

		Tree._RootNode = MountVirtualNode(Element, CreateHost(HostInstance, HostChildKey, {}))
		return Tree
	end

	function UnmountVirtualTree(Tree: Types.PractTree)
		if type(Tree) ~= "table" or Tree[Symbols_IsHeliumPractTree] ~= true then
			Debug.Error("invalid argument #1 to HeliumPract.Unmount (HeliumPract.Tree expected, got %q)", Tree)
		end

		Tree._Mounted = false

		local RootNode = Tree._RootNode
		if RootNode then
			UnmountVirtualNode(RootNode)
		end
	end

	Reconciler = {
		MountVirtualTree = MountVirtualTree;
		UpdateVirtualTree = UpdateVirtualTree;
		UnmountVirtualTree = UnmountVirtualTree;
		CreateHost = CreateHost;
	}

	return Reconciler
end

return CreateReconciler
