local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Knit)
local RagdollBinders = require(ServerStorage.Modules.Ragdoll.RagdollBinders)

local RagdollService = Knit.CreateService({
	Client = {};
	Name = "RagdollService";
})

function RagdollService:KnitStart()
	self.RagdollBinders:Start()
end

function RagdollService:KnitInit()
	self.RagdollBinders = RagdollBinders:Initialize()
end

return RagdollService
