--[=[
	Ragdolls the humanoid on death. Should be bound via [RagdollBindersClient].

	@client
	@class RagdollHumanoidOnDeathClient
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local FastRequire = require(ReplicatedStorage.Knit.Util.Additions.Utility.FastRequire)
local RagdollBinders = FastRequire(script.Parent.Parent.RagdollBinders)
local RagdollRigging = require(ReplicatedStorage.Knit.Util.Additions.Ragdoll.RagdollRigging)

local RagdollHumanoidOnDeathClient = setmetatable({}, BaseObject)
RagdollHumanoidOnDeathClient.ClassName = "RagdollHumanoidOnDeathClient"
RagdollHumanoidOnDeathClient.__index = RagdollHumanoidOnDeathClient

--[=[
	Constructs a new RagdollHumanoidOnDeathClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@return RagdollHumanoidOnDeathClient
]=]
function RagdollHumanoidOnDeathClient.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), RagdollHumanoidOnDeathClient)
	self.EnableFading = false
	self.RagdollBinder = RagdollBinders.Ragdoll

	if self.Object:GetState() == Enum.HumanoidStateType.Dead then
		self:HandleDeath()
	else
		self.Janitor:Add(self.Object.Died:Connect(function()
			self:HandleDeath(self.Object)
		end), "Disconnect", "DiedEvent")
	end

	return self
end

function RagdollHumanoidOnDeathClient:HandleDeath()
	-- Disconnect!
	self.Janitor:Remove("DiedEvent")
	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function() end;
		Some = function(Player: Player)
			if Player == Players.LocalPlayer then
				self.RagdollBinder:BindClient(self.Object)
			end
		end;
	})

	if self.EnableFading then
		local Character = self.Object.Parent
		task.delay(Players.RespawnTime - 0.5, function()
			if not Character:IsDescendantOf(Workspace) then
				return
			end

			-- fade into the mist...
			RagdollRigging.DisableParticleEmittersAndFadeOutYielding(Character, 0.4)
		end)
	end
end

function RagdollHumanoidOnDeathClient:__tostring()
	return "RagdollHumanoidOnDeath"
end

table.freeze(RagdollHumanoidOnDeathClient)
return RagdollHumanoidOnDeathClient
