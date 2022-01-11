local HeliumPractGlobalSystems = require(script.Parent.Parent.HeliumPractGlobalSystems)
local Join = require(script.Parent.Parent.Utility.Join)
local Symbols = require(script.Parent.Parent.Symbols)
local Types = require(script.Parent.Parent.Types)
local WithDeferredState = require(script.Parent.Parent.Hooks.WithDeferredState)
local WithLifecycle = require(script.Parent.Parent.Hooks.WithLifecycle)

local ENABLE_FREEZING = HeliumPractGlobalSystems.ENABLE_FREEZING

local INIT_EMPTY_STATE = if ENABLE_FREEZING then table.freeze({}) else {}
local INIT_EMPTY_PROPS = if ENABLE_FREEZING then table.freeze({}) else {}

local Symbols_None = Symbols.None

local function DeferredComponent(ComponentMethods: Types.ClassComponentMethods)
	local DefaultProperties = ComponentMethods.DefaultProperties
	local MetatableIndex = {__index = ComponentMethods}

	return WithDeferredState(function(GetState, SetState, SubscribeState)
		SetState(INIT_EMPTY_STATE)
		return WithLifecycle(function(QueueRedraw: () -> ())
			local UnsubscribeFunctionSet = {}
			local SelfNoMetatable: Types.ClassComponentSelf = {
				Properties = INIT_EMPTY_PROPS :: Types.PropertiesArgument;
				State = GetState() :: Types.ClassState;
				SetState = if ENABLE_FREEZING then function(self: Types.ClassComponentSelf, PartialStateUpdate: Types.ClassStateUpdate)
					local SaveState = GetState()
					if type(PartialStateUpdate) == "table" then
						local StateChanged = false
						for Key, NewValue in next, PartialStateUpdate do
							if NewValue == Symbols_None then
								NewValue = nil
							end

							if SaveState[Key] ~= NewValue then
								StateChanged = true
								break
							end
						end

						if StateChanged then
							local NewState = {}
							for Key, Value in next, SaveState do
								NewState[Key] = Value
							end

							for Key, Value in next, PartialStateUpdate do
								if Value == Symbols_None then
									Value = nil
								end

								NewState[Key] = Value
							end

							table.freeze(NewState)
							SetState(NewState)
						end
					else
						self:SetState((PartialStateUpdate :: Types.ClassStateUpdateThunk)(SaveState, self.Properties))
					end
				end else function(self: Types.ClassComponentSelf, PartialStateUpdate: Types.ClassStateUpdate)
					local SaveState = GetState()
					if type(PartialStateUpdate) == "table" then
						local StateChanged = false
						for Key, NewValue in next, PartialStateUpdate do
							if NewValue == Symbols_None then
								NewValue = nil
							end

							if SaveState[Key] ~= NewValue then
								StateChanged = true
								break
							end
						end

						if StateChanged then
							local NewState = {}
							for Key, Value in next, SaveState do
								NewState[Key] = Value
							end

							for Key, Value in next, PartialStateUpdate do
								if Value == Symbols_None then
									Value = nil
								end

								NewState[Key] = Value
							end

							SetState(NewState)
						end
					else
						self:SetState((PartialStateUpdate :: Types.ClassStateUpdateThunk)(SaveState, self.Properties))
					end
				end;

				SubscribeState = function(_, Function: () -> ())
					local Unsubscribe = SubscribeState(Function)
					UnsubscribeFunctionSet[Unsubscribe] = true
					return function()
						UnsubscribeFunctionSet[Unsubscribe] = nil
						Unsubscribe()
					end
				end;

				ForceRedraw = QueueRedraw;
				QueueRedraw = QueueRedraw;
			}

			local self = setmetatable(SelfNoMetatable, MetatableIndex)

			local function WrapOptionalLifecycleMethod(Name: string): ((Properties: Types.PropertiesArgument) -> ())?
				local Wrapped = self[Name]
				if Wrapped then
					return function(_Properties: Types.PropertiesArgument)
						Wrapped(self)
					end
				end

				return nil
			end

			local SelfRender = self.Render
			local SelfShouldUpdate = self.ShouldUpdate
			local SelfInitialize = self.Initialize
			local SelfWillUpdate

			do
				local WillUpdate = self.WillUpdate
				if WillUpdate then
					function SelfWillUpdate(NewProperties: Types.PropertiesArgument)
						WillUpdate(self, Join(INIT_EMPTY_PROPS, DefaultProperties, NewProperties), GetState())
					end
				end
			end

			return {
				Render = function(_Properties: Types.PropertiesArgument)
					return SelfRender(self)
				end;

				Initialize = function(Properties: Types.PropertiesArgument)
					self.Properties = Join(INIT_EMPTY_PROPS, DefaultProperties, Properties)
					if SelfInitialize then
						SelfInitialize(self)
					end

					self.State = GetState()
				end;

				DidMount = WrapOptionalLifecycleMethod("DidMount");
				WillUpdate = SelfWillUpdate;
				DidUpdate = WrapOptionalLifecycleMethod("DidUpdate");
				ShouldUpdate = function(NewProperties: Types.PropertiesArgument)
					NewProperties = Join(INIT_EMPTY_PROPS, DefaultProperties, NewProperties)
					local NewState = GetState()
					if SelfShouldUpdate then
						if SelfShouldUpdate(self, NewProperties, NewState) == false then
							self.State = GetState()
							self.Properties = NewProperties
							return false
						end

						NewState = GetState()
					end

					self.Properties = NewProperties
					self.State = NewState -- We set state here specifically

					return true
				end;

				WillUnmount = function(_Properties: Types.PropertiesArgument)
					local Functions = {}
					for Function in next, UnsubscribeFunctionSet do
						table.insert(Functions, Function)
					end

					for _, Function in ipairs(Functions) do
						task.spawn(Function)
					end

					if self.WillUnmount then
						self:WillUnmount()
					end
				end;
			}
		end)
	end)
end

return DeferredComponent
