export type RoactBinding<T> = {
	current: T,
	getValue: (RoactBinding<T>) -> T,
	map: (RoactBinding<T>, predicate: (value: T) -> T) -> RoactBinding<T>,
}

export type RoactContext<T> = {
	Consumer: any,
	Provider: any,
}

return false
