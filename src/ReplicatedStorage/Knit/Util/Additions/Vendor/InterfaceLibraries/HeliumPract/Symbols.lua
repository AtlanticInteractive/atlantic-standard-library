--- @typecheck mode: strict
local CreateSymbol = require(script.Parent.Utility.CreateSymbol)

local Symbols = {}

local ElementKinds = {}
ElementKinds.ContextConsumer = CreateSymbol("ContextConsumer")
ElementKinds.ContextProvider = CreateSymbol("ContextProvider")
ElementKinds.CreateInstance = CreateSymbol("CreateInstance")
ElementKinds.Decorate = CreateSymbol("Decorate")
ElementKinds.Index = CreateSymbol("Index")
ElementKinds.LifecycleComponent = CreateSymbol("LifecycleComponent")
ElementKinds.OnChild = CreateSymbol("OnChild")
ElementKinds.Portal = CreateSymbol("Portal")
ElementKinds.RenderComponent = CreateSymbol("RenderComponent")
ElementKinds.SiblingCluster = CreateSymbol("SiblingCluster")
ElementKinds.SignalComponent = CreateSymbol("SignalComponent")
ElementKinds.Stamp = CreateSymbol("Stamp")
ElementKinds.StateComponent = CreateSymbol("StateComponent")

Symbols.AttributeChangedSignals = CreateSymbol("AttributeChangedSymbols")
Symbols.Attributes = CreateSymbol("Attributes")
Symbols.Children = CreateSymbol("Children")
Symbols.CollectionServiceTags = CreateSymbol("CollectionServiceTags")
Symbols.OnMountWithHost = CreateSymbol("OnMountWithHost")
Symbols.OnUnmountWithHost = CreateSymbol("OnUnmountWithHost")
Symbols.OnUpdateWithHost = CreateSymbol("OnUpdateWithHost")
Symbols.PropertyChangedSignals = CreateSymbol("PropertyChangedSignals")

Symbols.ElementKind = CreateSymbol("ElementKind")
Symbols.ElementKinds = ElementKinds

Symbols.IsHeliumPractTree = CreateSymbol("IsHeliumPractTree")
Symbols.None = CreateSymbol("None")

table.freeze(ElementKinds)
table.freeze(Symbols)
return Symbols
