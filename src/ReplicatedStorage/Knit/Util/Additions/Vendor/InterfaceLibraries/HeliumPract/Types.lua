--- @typecheck mode: strict
export type ChildrenArgument = {[any]: Element | boolean | nil}
export type PropertiesArgument = {[any]: any}
export type Symbol = {} & typeof(setmetatable({}, {}))

-- Public types
export type Element = {[any]: any}

export type Component = (Properties: any) -> Element
export type ComponentTyped<PropsType> = (Properties: PropsType) -> Element
export type ClassState = {[string]: any}
export type ClassStateUpdateThunk = (State: ClassState, Properties: PropertiesArgument) -> ClassState
export type ClassStateUpdate = ClassState | ClassStateUpdateThunk
export type ClassComponentSelf = {
	[any]: any,
	Properties: PropertiesArgument,
	State: ClassState,

	QueueRedraw: (self: ClassComponentSelf) -> (),
	SetState: (self: ClassComponentSelf, PartialStateUpdate: ClassStateUpdate) -> (),
	SubscribeState: (self: ClassComponentSelf, Listener: () -> ()) -> (() -> ()),
}

export type ClassComponentMethods = {
	[any]: any,
	DefaultProperties: {[string]: any}?,
	Render: (self: ClassComponentSelf) -> Element,
	Initialize: ((self: ClassComponentSelf) -> ())?,
	DidMount: ((self: ClassComponentSelf) -> ())?,
	ShouldUpdate: ((self: ClassComponentSelf, NewProperties: PropertiesArgument, NewState: ClassState) -> boolean)?,
	WillUpdate: ((self: ClassComponentSelf, NewProperties: PropertiesArgument, NewState: ClassState) -> ())?,
	DidUpdate: ((self: ClassComponentSelf) -> ())?,
	WillUnmount: ((self: ClassComponentSelf) -> ())?,
}

export type Lifecycle = {
	Render: Component,
	Initialize: ((Properties: any) -> ())?,
	DidMount: ((Properties: any) -> ())?,
	ShouldUpdate: ((NewProperties: any, OldProperties: any) -> boolean)?,
	WillUpdate: ((Properties: any, OldProperties: any) -> ())?,
	DidUpdate: ((Properties: any) -> ())?,
	WillUnmount: ((Properties: any) -> ())?,
}

export type ContextProvider = {
	Find: (Name: string) -> any?,
	Provide: (Name: string, Object: any?) -> (),
	Unprovide: (Name: string) -> (),
}

export type HostContext = {
	-- Immutable type used as an object reference passed down in trees; the
	-- purpose of grouping these together is because typically components
	-- share the same host and context information except in special cases.
	-- This reduces memory usage and simplifies node visiting processes.
	ChildKey: string?,
	Instance: Instance?,
	Providers: {ContextProvider},
}

export type VirtualNode = {
	[any]: any,
	_CurrentElement: Element,
	_HostContext: HostContext,
	_WasUnmounted: boolean,
}

export type PractTree = {
	[Symbol]: any,
	_Mounted: boolean,
	_RootNode: VirtualNode?,
}

export type Reconciler = {
	CreateHost: (Instance: Instance?, Key: string?, Providers: {ContextProvider}) -> HostContext,
	MountVirtualTree: (Element: Element, HostInstance: Instance?, HostKey: string?) -> PractTree,
	UnmountVirtualTree: (Tree: PractTree) -> (),
	UpdateVirtualTree: (Tree: PractTree, NewElement: Element) -> (),
}

return false
