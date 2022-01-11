--[=[
	Holds binders for [Cooldown].
	@class CooldownBindersClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Binder = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.Binder)
local BinderProvider = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.BinderProvider)

return BinderProvider.new(function(self)
	--[=[
	@prop Cooldown Binder<CooldownClient>
	@within CooldownBindersClient
]=]
	self:Add(Binder.new("Cooldown", require(script.Parent.Cooldown)))
end)
