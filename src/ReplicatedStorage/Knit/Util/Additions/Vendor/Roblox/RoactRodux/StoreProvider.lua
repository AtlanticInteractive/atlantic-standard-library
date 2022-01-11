local Roact = require(script.Parent.Parent.Roact)
local StoreContext = require(script.Parent.StoreContext)

local StoreProvider = Roact.PureComponent:extend("StoreProvider")

function StoreProvider:init(props)
	self.store = assert(props.store, "Error initializing StoreProvider. Expected a `store` prop to be a Rodux store.")
end

function StoreProvider:render()
	return Roact.createElement(StoreContext.Provider, {
		value = self.store,
	}, Roact.oneChild(self.props[Roact.Children]))
end

return StoreProvider
