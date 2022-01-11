local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Binder = require(ReplicatedStorage.Knit.Util.Additions.Classes.Binders.Binder)
local HumanoidTracker = require(ReplicatedStorage.Knit.Util.Additions.Classes.HumanoidTracker)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)

local PlayerHumanoidBinder = setmetatable({}, Binder)
PlayerHumanoidBinder.ClassName = "PlayerHumanoidBinder"
PlayerHumanoidBinder.__index = PlayerHumanoidBinder

function PlayerHumanoidBinder.new(Tag, Class, ...)
	local self = setmetatable(Binder.new(Tag, Class, ...), PlayerHumanoidBinder)
	self.Janitor = Janitor.new()
	self.Janitor:Add(self.Janitor, "Destroy")

	self.ShouldTag = self.Janitor:Add(Instance.new("BoolValue"), "Destroy")
	self.ShouldTag.Value = true

	return self
end

function PlayerHumanoidBinder:SetAutomaticTagging(ShouldTag)
	assert(type(ShouldTag) == "boolean", "Bad shouldTag")
	assert(self.ShouldTag, "Missing self._shouldTag")

	self.ShouldTag.Value = ShouldTag
end

function PlayerHumanoidBinder:Start()
	local Results = {getmetatable(PlayerHumanoidBinder).Start(self)}

	self.Janitor:Add(self.ShouldTag.Changed:Connect(function()
		self:_BindTagging(true)
	end), "Disconnect")

	self:_BindTagging()
	return table.unpack(Results)
end

function PlayerHumanoidBinder:_BindTagging(DoUnbinding)
	if self.ShouldTag.Value then
		local TaggingJanitor = self.Janitor:Add(Janitor.new(), "Destroy", "Tagging")
		local PlayerJanitors = TaggingJanitor:Add(Janitor.new(), "Destroy")
		TaggingJanitor:Add(Players.PlayerAdded:Connect(function(Player)
			self:_HandlePlayerAdded(PlayerJanitors, Player)
		end), "Disconnect")

		TaggingJanitor:Add(Players.PlayerRemoving:Connect(function(Player)
			PlayerJanitors:Remove(Player)
		end), "Disconnect")

		for _, Player in ipairs(Players:GetPlayers()) do
			self:_HandlePlayerAdded(PlayerJanitors, Player)
		end
	else
		self.Janitor:Remove("Tagging")

		if DoUnbinding then
			for _, Player in ipairs(Players:GetPlayers()) do
				local Character = Player.Character
				local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
				if Humanoid then
					self:Unbind(Humanoid)
				end
			end
		end
	end
end

function PlayerHumanoidBinder:_HandlePlayerAdded(PlayerJanitors, Player)
	local PlayerJanitor = PlayerJanitors:Add(Janitor.new(), "Destroy", Player)
	local Tracker = PlayerJanitor:Add(HumanoidTracker.new(Player), "Destroy")

	local function HandleHumanoid(NewHumanoid)
		if NewHumanoid then
			self:Bind(NewHumanoid)
		end
	end

	PlayerJanitor:Add(Tracker.Humanoid.Changed:Connect(HandleHumanoid), "Disconnect")
	HandleHumanoid(Tracker.Humanoid.Value)
end

return PlayerHumanoidBinder
