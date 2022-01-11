--!strict
-- Created by DataBrain, licensed as public domain.

-- See this website for an in-depth Pract Documentation:
-- https://ambers-careware.github.io/pract/
local CreateReconciler = require(script.CreateReconciler)
local HeliumPractGlobalSystems = require(script.HeliumPractGlobalSystems)
local Symbols = require(script.Symbols)
local Types = require(script.Types)

local HeliumPract = {}
HeliumPract._VERSION = "0.9.7"

HeliumPractGlobalSystems.Run()

-- Public types
export type ChildrenArgument = Types.ChildrenArgument
export type ClassComponentMethods = Types.ClassComponentMethods
export type ClassState = Types.ClassState
export type Component = Types.Component
export type ComponentTyped<PropsType> = Types.ComponentTyped<PropsType>
export type Element = Types.Element
export type Lifecycle = Types.Lifecycle
export type PropertiesArgument = Types.PropertiesArgument
export type Tree = Types.PractTree

-- Public library values

-- Base element functions
HeliumPract.Combine = require(script.Functions.Combine)
HeliumPract.CreateElement = require(script.Functions.CreateElement)
HeliumPract.CreateElementTyped = (HeliumPract.CreateElement :: any) :: <PropsType>(Component: ComponentTyped<PropsType>, Properties: PropsType) -> (Types.Element)
HeliumPract.Decorate = require(script.Functions.Decorate)
HeliumPract.Index = require(script.Functions.Index)
HeliumPract.Portal = require(script.Functions.Portal)
HeliumPract.Stamp = require(script.Functions.Stamp)

-- Virtual tree functions
local RobloxReconciler = CreateReconciler()
HeliumPract.Mount = RobloxReconciler.MountVirtualTree
HeliumPract.Update = RobloxReconciler.UpdateVirtualTree
HeliumPract.Unmount = RobloxReconciler.UnmountVirtualTree

-- Higher-order component wrapper functions

HeliumPract.Component = require(script.Components.Component)
HeliumPract.DeferredComponent = require(script.Components.DeferredComponent)
HeliumPract.WithContextConsumer = require(script.Hooks.WithContextConsumer)
HeliumPract.WithContextProvider = require(script.Hooks.WithContextProvider)
HeliumPract.WithDeferredState = require(script.Hooks.WithDeferredState)
HeliumPract.WithLifecycle = require(script.Hooks.WithLifecycle)
HeliumPract.WithSignal = require(script.Hooks.WithSignal)
HeliumPract.WithState = require(script.Hooks.WithState)

-- Symbols:

-- Decoration prop key symbols
HeliumPract.AttributeChangedSignals = Symbols.AttributeChangedSignals
HeliumPract.Attributes = Symbols.Attributes
HeliumPract.Children = Symbols.Children
HeliumPract.CollectionServiceTags = Symbols.CollectionServiceTags
HeliumPract.OnMountWithHost = Symbols.OnMountWithHost
HeliumPract.OnUnmountWithHost = Symbols.OnUnmountWithHost
HeliumPract.OnUpdateWithHost = Symbols.OnUpdateWithHost
HeliumPract.PropertyChangedSignals = Symbols.PropertyChangedSignals

HeliumPract.None = Symbols.None

table.freeze(HeliumPract)
return HeliumPract
