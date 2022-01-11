--[=[
	Holds binders
	@server
	@class IKBinders
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Binder = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.Binder)
local BinderProvider = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.BinderProvider)

return BinderProvider.new(function(self)
	self:Add(Binder.new("IKRig", require(script.Parent.Rig.IKRig)))
	self:Add(Binder.new("IKRightGrip", require(ReplicatedStorage.Knit.Util.Additions.IK.Grip.IKRightGrip)))
	self:Add(Binder.new("IKLeftGrip", require(ReplicatedStorage.Knit.Util.Additions.IK.Grip.IKLeftGrip)))
end)
