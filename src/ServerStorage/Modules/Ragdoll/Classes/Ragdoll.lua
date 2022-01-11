--[=[
	Base class for ragdolls, meant to be used with binders. See [RagdollBindersServer].
	While a humanoid is bound with this class, it is ragdolled.

	```lua
	-- Be sure to do the service init on the client too
	local serviceBag = require("ServiceBag")
	local ragdollBindersServer = serviceBag:GetService(require("RagdollBindersServer"))

	serviceBag:Init()
	serviceBag:Start()

	-- Enable ragdoll
	ragdollBindersServer.Ragdoll:Bind(humanoid)

	-- Disable ragdoll
	ragdollBindersServer.Ragdoll:Unbind(humanoid)
	```

	@class Ragdoll
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)

local Ragdoll = setmetatable({}, BaseObject)
Ragdoll.ClassName = "Ragdoll"
Ragdoll.__index = Ragdoll

--[=[
	Constructs a new Ragdoll. Should be done via [Binder]. See [RagdollBindersServer].
	@param humanoid Humanoid
	@return Ragdoll
]=]
function Ragdoll.new(Humanoid: Humanoid)
	return setmetatable(BaseObject.new(Humanoid), Ragdoll)
end

function Ragdoll:__tostring()
	return "Ragdoll"
end

table.freeze(Ragdoll)
return Ragdoll
