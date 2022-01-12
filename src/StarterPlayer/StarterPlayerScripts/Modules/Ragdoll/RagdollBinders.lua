--[=[
	Holds binders for Ragdolls on the client. Be sure to initialize on the server. See [RagdollBindersClient] for details.
	Be sure to use a [ServiceBag] to initialize this service.

	```lua
	-- Client.lua

	local serviceBag = require("ServiceBag")
	serviceBag:GetService(require("RagdollBindersClient"))

	serviceBag:Init()
	serviceBag:Start()
	```

	@client
	@class RagdollBindersClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Binder = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.Binder)
local BinderProvider = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.BinderProvider)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)

return BinderProvider.new(function(self)
	--[=[
	Apply this binder to a humanoid to ragdoll it. Humanoid must already have [Ragdollable] defined.

	```lua
	local ragdoll = serviceBag:GetService(RagdollBindersClient).Ragdoll:Get(humanoid)
	if ragdoll then
		print("Is ragdolled")
	else
		print("Not ragdolled")
	end
	```
	@prop Ragdoll Binder<RagdollClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("Ragdoll", FastRequire(script.Parent.Classes.Ragdoll)))

	--[=[
	Enables ragdolling on a humanoid.
	@prop Ragdollable Binder<RagdollableClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("Ragdollable", FastRequire(script.Parent.Classes.Ragdollable)))

	--[=[
	Automatically applies ragdoll upon humanoid death.
	@prop RagdollHumanoidOnDeath Binder<RagdollHumanoidOnDeathClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("RagdollHumanoidOnDeath", FastRequire(script.Parent.Classes.RagdollHumanoidOnDeath)))

	--[=[
	Automatically applies ragdoll upon humanoid fall.
	@prop RagdollHumanoidOnFall Binder<RagdollHumanoidOnFallClient>
	@within RagdollBindersClient
]=]
	self:Add(Binder.new("RagdollHumanoidOnFall", FastRequire(script.Parent.Classes.RagdollHumanoidOnFall)))
end)
