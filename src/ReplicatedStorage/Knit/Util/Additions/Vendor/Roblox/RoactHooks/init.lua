local createUseBinding = require(script.createUseBinding)
local createUseCallback = require(script.createUseCallback)
local createUseContext = require(script.createUseContext)
local createUseEffect = require(script.createUseEffect)
local createUseMemo = require(script.createUseMemo)
local createUseReducer = require(script.createUseReducer)
local createUseState = require(script.createUseState)
local createUseToggle = require(script.createUseToggle)
local createUseValue = require(script.createUseValue)

local _Roact = require(script.Parent.Roact)

local Hooks = {}

type Roact = _Roact.Roact
type RoactBinding<T> = _Roact.RoactBinding<T>
type RoactContext<T> = _Roact.RoactContext<T>

type BasicStateAction<S> = ((state: S) -> S) | S
type CreateFunction = (() -> () -> ()) | () -> ()
type Dispatch<A> = (a: A) -> ()
type SetFunction<T> = (newValue: T) -> ()

export type HookOptions = {
	componentType: string?,
	defaultProps: {[any]: any}?,
	name: string?,
	validateProps: ((props: {[any]: any}?) -> (any, string?))?,
}

export type HooksList = {
	useBinding: <T>(defaultValue: T) -> (RoactBinding<T>, SetFunction<T>),
	useCallback: <T>(callback: T, dependencies: {any}?) -> T,
	useContext: <T>(context: RoactContext<T>) -> T,
	useEffect: (create: CreateFunction, dependencies: {any}?) -> (),
	useMemo: <T>(create: () -> T, dependencies: {any}?) -> T,
	useReducer: <S, I, A>(reducer: (state: S, action: A) -> S, initialState: I) -> (S, Dispatch<A>),
	useState: <S>(initialState: (() -> S) | S) -> (S, Dispatch<BasicStateAction<S>>),
	useToggle: (initialState: boolean) -> (boolean, Dispatch<BasicStateAction<boolean>>),
	useValue: <T>(defaultValue: T) -> {value: T},

	UseBinding: <T>(defaultValue: T) -> (RoactBinding<T>, SetFunction<T>),
	UseCallback: <T>(callback: T, dependencies: {any}?) -> T,
	UseContext: <T>(context: RoactContext<T>) -> T,
	UseEffect: (create: CreateFunction, dependencies: {any}?) -> (),
	UseMemo: <T>(create: () -> T, dependencies: {any}?) -> T,
	UseReducer: <S, I, A>(reducer: (state: S, action: A) -> S, initialState: I) -> (S, Dispatch<A>),
	UseState: <S>(initialState: (() -> S) | S) -> (S, Dispatch<BasicStateAction<S>>),
	UseToggle: (initialState: boolean) -> (boolean, Dispatch<BasicStateAction<boolean>>),
	UseValue: <T>(defaultValue: T) -> {value: T},
}

-- stylua: ignore
export type HookFunction = (
	Render: (props: {[any]: any}, hooks: HooksList) -> any,
	Options: HookOptions?
) -> any

local function createHooks(roact, component)
	local useEffect = createUseEffect(component)
	local useState = createUseState(component)
	local useValue = createUseValue(component)

	local useBinding = createUseBinding(roact, useValue)
	local useContext = createUseContext(component, useEffect, useState)
	local useMemo = createUseMemo(useValue)

	local useCallback = createUseCallback(useMemo)

	local useReducer = createUseReducer(useCallback, useState)
	local useToggle = createUseToggle(useCallback, useState)

	return {
		useBinding = useBinding;
		useCallback = useCallback;
		useContext = useContext;
		useEffect = useEffect;
		useMemo = useMemo;
		useReducer = useReducer;
		useState = useState;
		useToggle = useToggle;
		useValue = useValue;

		UseBinding = useBinding;
		UseCallback = useCallback;
		UseContext = useContext;
		UseEffect = useEffect;
		UseMemo = useMemo;
		UseReducer = useReducer;
		UseState = useState;
		UseToggle = useToggle;
		UseValue = useValue;
	}
end

function Hooks.new(roact: Roact)
	return function(render: HookFunction, possibleOptions: HookOptions?)
		assert(type(render) == "function", "Hooked components must be functions.")
		local options = possibleOptions or {}
		local componentType = options.componentType
		local name = options.name or debug.info(render, "n")

		local classComponent

		if componentType == nil or componentType == "Component" then
			classComponent = roact.Component:extend(name)
		elseif componentType == "PureComponent" then
			classComponent = roact.PureComponent:extend(name)
		else
			error(string.format("'%s' is not a valid componentType. componentType must either be nil, 'Component', or 'PureComponent'", tostring(componentType)))
		end

		classComponent.defaultProps = options.defaultProps
		classComponent.validateProps = options.validateProps

		function classComponent:init()
			self.defaultStateValues = {}
			self.effectDependencies = {}
			self.effects = {}
			self.unmountEffects = {}

			self.hooks = createHooks(roact, self)
		end

		function classComponent:runEffects()
			local effects = self.effects
			local effectDependencies = self.effectDependencies
			local unmountEffects = self.unmountEffects

			for index = 1, self.hookCounter do
				local effectData = effects[index]
				if effectData == nil then
					continue
				end

				local effect, dependsOn = effectData[1], effectData[2]

				if dependsOn ~= nil then
					local lastDependencies = effectDependencies[index]
					if lastDependencies ~= nil then
						local anythingChanged = false

						for dependencyIndex, dependency in ipairs(dependsOn) do
							if lastDependencies[dependencyIndex] ~= dependency then
								anythingChanged = true
								break
							end
						end

						if not anythingChanged then
							continue
						end
					end

					effectDependencies[index] = dependsOn
				end

				local unmountEffect = unmountEffects[index]
				if unmountEffect ~= nil then
					unmountEffect()
				end

				unmountEffects[index] = effect()
			end
		end

		classComponent.didMount = classComponent.runEffects
		classComponent.didUpdate = classComponent.runEffects

		function classComponent:willUnmount()
			local unmountEffects = self.unmountEffects
			for index = 1, self.hookCounter do
				local unmountEffect = unmountEffects[index]

				if unmountEffect ~= nil then
					unmountEffect()
				end
			end
		end

		function classComponent:render()
			self.hookCounter = 0

			return render(self.props, self.hooks)
		end

		return classComponent
	end
end

table.freeze(Hooks)
return Hooks
