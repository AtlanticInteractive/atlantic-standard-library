--[=[
	Holds binders for [Cooldown].
	@class CooldownBindersServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Binder = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.Binder)
local BinderProvider = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.BinderProvider)

return BinderProvider.new(function(self)
	--[=[
	@prop Cooldown Binder<Cooldown>
	@within CooldownBindersServer
]=]
	self:Add(Binder.new("Cooldown", require(script.Parent.Cooldown)))
end)
