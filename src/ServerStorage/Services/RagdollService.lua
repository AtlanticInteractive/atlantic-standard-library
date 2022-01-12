--[=[
	Handles ragdolling on the server.

	@server
	@class RagdollService
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Knit)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local PromiseChildOfClass = require(ReplicatedStorage.Knit.Util.Additions.Promises.PromiseChildOfClass)
local RagdollBinders = require(ServerStorage.Modules.Ragdoll.RagdollBinders)

local RagdollService = Knit.CreateService({
	Client = {};
	Name = "RagdollService";
})

--[=[
	@prop AutomaticallyUnragdoll boolean
	@readonly
	@within RagdollService
	Whether or not players will automatically recover from a ragdoll.
]=]
RagdollService.AutomaticallyUnragdoll = true

--[=[
	@prop SetGlobalRagdollBehavior RemoteSignal<BehaviorName: string, Humanoid: Humanoid, IsEnabled: boolean>
	@tag Client
	@within RagdollService
]=]
RagdollService.Client.SetGlobalRagdollBehavior = Knit.CreateSignal()

local PlayerJanitors = Janitor.new()

--[=[
	Sets if a specific humanoid is ragdollable.
	@param Humanoid Humanoid
	@param IsRagdollable boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollableHumanoid(Humanoid: Humanoid, IsRagdollable: boolean)
	self.Client.SetGlobalRagdollBehavior:FireAll("Ragdollable", Humanoid, IsRagdollable)
	return self
end

--[=[
	Sets if a specific humanoid is ragdolled.
	@param Humanoid Humanoid
	@param DoRagdollHumanoid boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollHumanoid(Humanoid: Humanoid, DoRagdollHumanoid: boolean)
	self.Client.SetGlobalRagdollBehavior:FireAll("Ragdoll", Humanoid, DoRagdollHumanoid)
	return self
end

--[=[
	Sets if a specific humanoid is ragdolled when they die.
	@param Humanoid Humanoid
	@param DoRagdollHumanoidOnDeath boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollHumanoidOnDeath(Humanoid: Humanoid, DoRagdollHumanoidOnDeath: boolean)
	self.Client.SetGlobalRagdollBehavior:FireAll("RagdollHumanoidOnDeath", Humanoid, DoRagdollHumanoidOnDeath)
	return self
end

--[=[
	Sets if a specific humanoid is ragdolled when they fall.
	@param Humanoid Humanoid
	@param DoRagdollHumanoidOnFall boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollHumanoidOnFall(Humanoid: Humanoid, DoRagdollHumanoidOnFall: boolean)
	self.Client.SetGlobalRagdollBehavior:FireAll("RagdollHumanoidOnFall", Humanoid, DoRagdollHumanoidOnFall)
	return self
end

--[=[
	Sets the AutomaticallyUnragdoll property and updates accordingly.
	@param AutomaticallyUnragdoll boolean
	@return RagdollService
]=]
function RagdollService:SetAutomaticallyUnragdoll(AutomaticallyUnragdoll: boolean)
	if self.AutomaticallyUnragdoll ~= AutomaticallyUnragdoll then
		self.AutomaticallyUnragdoll = AutomaticallyUnragdoll
		local UnragdollAutomatically = self.RagdollBinders.UnragdollAutomatically

		local MatchTable = {
			None = function() end;
			Some = function(Humanoid: Humanoid)
				if AutomaticallyUnragdoll then
					if not UnragdollAutomatically:Get(Humanoid) then
						UnragdollAutomatically:Bind(Humanoid)
					end
				else
					if UnragdollAutomatically:Get(Humanoid) then
						UnragdollAutomatically:Unbind(Humanoid)
					end
				end
			end;
		}

		for _, Player in ipairs(Players:GetPlayers()) do
			CharacterUtility.GetPlayerHumanoid(Player):Match(MatchTable)
		end
	end

	return self
end

--[=[
	Sets if a specific player is ragdolled.
	@param Player Player
	@param DoRagdollPlayer boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollPlayer(Player: Player, DoRagdollPlayer: boolean)
	local Ragdoll = self.RagdollBinders.Ragdoll
	CharacterUtility.GetPlayerHumanoid(Player):Match({
		None = function() end;
		Some = function(Humanoid: Humanoid)
			if DoRagdollPlayer then
				if not Ragdoll:Get(Humanoid) then
					Ragdoll:Bind(Humanoid)
				end
			else
				if Ragdoll:Get(Humanoid) then
					Ragdoll:Unbind(Humanoid)
				end
			end
		end;
	})

	return self
end

--[=[
	Sets if a specific player is ragdolled when they die.
	@param Player Player
	@param DoRagdollPlayerOnDeath boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollPlayerOnDeath(Player: Player, DoRagdollPlayerOnDeath: boolean)
	local RagdollHumanoidOnDeath = self.RagdollBinders.RagdollHumanoidOnDeath
	CharacterUtility.GetPlayerHumanoid(Player):Match({
		None = function() end;
		Some = function(Humanoid: Humanoid)
			if DoRagdollPlayerOnDeath then
				if not RagdollHumanoidOnDeath:Get(Humanoid) then
					RagdollHumanoidOnDeath:Bind(Humanoid)
				end
			else
				if RagdollHumanoidOnDeath:Get(Humanoid) then
					RagdollHumanoidOnDeath:Unbind(Humanoid)
				end
			end
		end;
	})

	return self
end

--[=[
	Sets if a specific player is ragdolled when they fall.
	@param Player Player
	@param DoRagdollPlayerOnFall boolean
	@return RagdollService
]=]
function RagdollService:SetRagdollPlayerOnFall(Player: Player, DoRagdollPlayerOnFall: boolean)
	local RagdollHumanoidOnFall = self.RagdollBinders.RagdollHumanoidOnFall
	CharacterUtility.GetPlayerHumanoid(Player):Match({
		None = function() end;
		Some = function(Humanoid: Humanoid)
			if DoRagdollPlayerOnFall then
				if not RagdollHumanoidOnFall:Get(Humanoid) then
					RagdollHumanoidOnFall:Bind(Humanoid)
				end
			else
				if RagdollHumanoidOnFall:Get(Humanoid) then
					RagdollHumanoidOnFall:Unbind(Humanoid)
				end
			end
		end;
	})

	return self
end

function RagdollService:KnitStart()
	self.RagdollBinders:Start()

	local function PlayerAdded(Player: Player)
		local PlayerJanitor = PlayerJanitors:Add(Janitor.new(), "Destroy", Player)
		local function CharacterAdded(Character: Model)
			PlayerJanitor:Add(Janitor.new(), "Destroy", "CharacterJanitor"):AddPromise(PromiseChildOfClass(Character, "Humanoid", 15)):Then(function(Humanoid: Humanoid)
				self.RagdollBinders.Ragdollable:Bind(Humanoid)
				if self.AutomaticallyUnragdoll then
					self.RagdollBinders.UnragdollAutomatically:Bind(Humanoid)
				end
			end):Catch(CatchFactory("PromiseChildOfClass"))
		end

		local function CharacterRemoving()
			PlayerJanitor:Remove("CharacterJanitor")
		end

		PlayerJanitor:Add(Player.CharacterRemoving:Connect(CharacterRemoving), "Disconnect")
		CharacterAdded(Player.Character or Player.CharacterAdded:Wait())
		PlayerJanitor:Add(Player.CharacterAdded:Connect(CharacterAdded), "Disconnect")
	end

	local function PlayerRemoving(Player: Player)
		PlayerJanitors:Remove(Player)
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
	for _, Player in ipairs(Players:GetPlayers()) do
		if PlayerJanitors:Get(Player) then
			continue
		end

		task.spawn(PlayerAdded, Player)
	end
end

function RagdollService:KnitInit()
	self.RagdollBinders = RagdollBinders:Initialize()
end

return RagdollService
