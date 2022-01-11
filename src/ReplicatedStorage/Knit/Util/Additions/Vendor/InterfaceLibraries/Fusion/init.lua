--!strict

--[[
	The entry point for the Fusion library.
]]

local PubTypes = require(script.PubTypes)
local restrictRead = require(script.Utility.restrictRead)

export type StateObject<T> = PubTypes.StateObject<T>
export type CanBeState<T> = PubTypes.CanBeState<T>
export type Symbol = PubTypes.Symbol
export type Value<T> = PubTypes.Value<T>
export type Computed<T> = PubTypes.Computed<T>
export type ComputedPairs<K, V> = PubTypes.ComputedPairs<K, V>
export type Observer = PubTypes.Observer
export type Tween<T> = PubTypes.Tween<T>
export type Spring<T> = PubTypes.Spring<T>

type PossibleElement = string | (Properties: PubTypes.PropertyTable) -> Instance

type Fusion = {
	New: (className: string) -> ((propertyTable: PubTypes.PropertyTable) -> Instance),
	Children: PubTypes.ChildrenKey,
	OnEvent: (eventName: string) -> PubTypes.OnEventKey,
	OnChange: (propertyName: string) -> PubTypes.OnChangeKey,

	CreateElement: (Element: PossibleElement, Properties: PubTypes.PropertyTable?, Children: {[any]: Instance}?) -> Instance,
	Event: {[string]: PubTypes.OnEventKey},
	Change: {[string]: PubTypes.OnChangeKey},

	Value: <T>(initialValue: T) -> Value<T>,
	Computed: <T>(callback: () -> T) -> Computed<T>,
	ComputedPairs: <K, VI, VO>(inputTable: CanBeState<{[K]: VI}>, processor: (K, VI) -> VO, destructor: (VO) -> ()?) -> ComputedPairs<K, VO>,
	Observer: (watchedState: StateObject<any>) -> Observer,

	Tween: <T>(goalState: StateObject<T>, tweenInfo: TweenInfo?) -> Tween<T>,
	Spring: <T>(goalState: StateObject<T>, speed: number?, damping: number?) -> Spring<T>,
}

return restrictRead("Fusion", {
	New = require(script.Instances.New);
	Children = require(script.Instances.Children);
	OnEvent = require(script.Instances.OnEvent);
	OnChange = require(script.Instances.OnChange);

	CreateElement = require(script.Instances.CreateElement);
	Event = require(script.Instances.Event);
	Change = require(script.Instances.Change);

	Value = require(script.State.Value);
	Computed = require(script.State.Computed);
	ComputedPairs = require(script.State.ComputedPairs);
	Observer = require(script.State.Observer);

	Tween = require(script.Animation.Tween);
	Spring = require(script.Animation.Spring);
}) :: Fusion
