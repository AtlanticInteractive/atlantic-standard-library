--[=[
	Ragdolls the humanoid on death. Should be bound via [RagdollBindersClient].

	@client
	@class RagdollHumanoidOnFallClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local BindableRagdollHumanoidOnFall = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.Classes.BindableRagdollHumanoidOnFall)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)
local RagdollHumanoidOnFallConstants = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.Classes.RagdollHumanoidOnFallConstants)

local RagdollHumanoidOnFallClient = setmetatable({}, BaseObject)
RagdollHumanoidOnFallClient.ClassName = "RagdollHumanoidOnFallClient"
RagdollHumanoidOnFallClient.__index = RagdollHumanoidOnFallClient

require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("PromiseRemoteEventMixin")):Add(RagdollHumanoidOnFallClient, RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME)

--[=[
	Constructs a new RagdollHumanoidOnFallClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@param serviceBag ServiceBag
	@return RagdollHumanoidOnFallClient
]=]
function RagdollHumanoidOnFallClient.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), RagdollHumanoidOnFallClient)
	self.RagdollBinder = RagdollBinders.Ragdoll

	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function() end;
		Some = function(Player: Player)
			if Player == Players.LocalPlayer then
				self.RagdollLogic = self.Janitor:Add(BindableRagdollHumanoidOnFall.new(self.Object, self.RagdollBinder), "Destroy")

				self.Janitor:Add(self.RagdollLogic.ShouldRagdoll.Changed:Connect(function()
					self:Update()
				end), "Disconnect")
			end
		end;
	})

	return self
end

function RagdollHumanoidOnFallClient:Update()
	if self.RagdollLogic.ShouldRagdoll.Value then
		self.RagdollBinder:BindClient(self.Object)
		self:PromiseRemoteEvent():Then(function(RemoteEvent: RemoteEvent)
			RemoteEvent:FireServer(true)
		end):Catch(CatchFactory("RagdollHumanoidOnFallClient.PromiseRemoteEvent"))
	end
end

function RagdollHumanoidOnFallClient:__tostring()
	return "RagdollHumanoidOnFall"
end

table.freeze(RagdollHumanoidOnFallClient)
return RagdollHumanoidOnFallClient
