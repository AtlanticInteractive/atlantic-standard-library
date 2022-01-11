--[=[
	Tracks a player's character's humanoid
	@class HumanoidTracker
]=]

local Janitor = require(script.Parent.Parent.Parent.Janitor)
local Promise = require(script.Parent.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Parent.Signal)
local ValueObject = require(script.Parent.ValueObject)

local HumanoidTracker = {}
HumanoidTracker.ClassName = "HumanoidTracker"
HumanoidTracker.__index = HumanoidTracker

--[=[
	Current humanoid.
	@prop Humanoid ValueObject<Humanoid>
	@within HumanoidTracker
]=]

--[=[
	Current humanoid which is alive.
	@prop AliveHumanoid ValueObject<Humanoid>
	@within HumanoidTracker
]=]

--[=[
	Fires when the humanoid dies.
	@prop HumanoidDied Signal<Humanoid>
	@within HumanoidTracker
]=]

local function OnCharacterChanged(self)
	local CharacterJanitor = self.Janitor:Add(Janitor.new(), "Destroy", "CharacterJanitor")
	local Character = self.Player.Character
	if not Character then
		self.Humanoid.Value = nil
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		self.Humanoid.Value = Humanoid -- TODO: Track if this humanoid goes away
		return
	end

	self.Humanoid.Value = nil
	CharacterJanitor:Add(Character.ChildAdded:Connect(function(Child)
		if Child:IsA("Humanoid") then
			CharacterJanitor:Remove("ChildAdded")
			self.Humanoid.Value = Child
		end
	end), "Disconnect", "ChildAdded")
end

local function HandleHumanoidChanged(self, NewHumanoid: Humanoid, ValueJanitor)
	if not NewHumanoid then
		self.AliveHumanoid.Value = nil
		return
	end

	if NewHumanoid.Health <= 0 then
		self.AliveHumanoid.Value = nil
		return
	end

	self.AliveHumanoid.Value = NewHumanoid
	local Alive = true
	ValueJanitor:Add(function()
		Alive = false
	end, true)

	ValueJanitor:Add(NewHumanoid.Died:Connect(function()
		if not Alive then
			return
		end

		self.AliveHumanoid.Value = nil
		if self.Destroy then
			self.HumanoidDied:Fire(NewHumanoid)
		end
	end), "Disconnect")
end

--[=[
	Tracks the player's current humanoid.

	:::tip
	Be sure to clean up the tracker once you're done!
	:::

	@param Player Player
	@return HumanoidTracker
]=]
function HumanoidTracker.new(Player: Player)
	local self = setmetatable({
		AliveHumanoid = nil;
		Humanoid = nil;
		HumanoidDied = nil;

		Player = Player;
		Janitor = Janitor.new();
	}, HumanoidTracker)

	self.AliveHumanoid = self.Janitor:Add(ValueObject.new(), "Destroy")
	self.Humanoid = self.Janitor:Add(ValueObject.new(), "Destroy")
	self.HumanoidDied = Signal.new(self.Janitor)

	self.Janitor:Add(self.Humanoid.Changed:Connect(function(NewHumanoid, _, ValueJanitor)
		if self.Destroy then
			HandleHumanoidChanged(self, NewHumanoid, ValueJanitor)
		end
	end), "Disconnect")

	self.Janitor:Add(self.Player:GetPropertyChangedSignal("Character"):Connect(function()
		if self.Destroy then
			OnCharacterChanged(self)
		end
	end), "Disconnect")

	OnCharacterChanged(self)
	return self
end

--[=[
	Returns a promise that resolves when the next humanoid is found.
	If a humanoid is already there, then returns a resolved promise
	with that humanoid.

	@return Promise<Humanoid>
]=]
function HumanoidTracker:PromiseNextHumanoid()
	if self.Humanoid.Value then
		return Promise.Resolve(self.Humanoid.Value)
	end

	local NextHumanoidPromise = self.Janitor:Get("NextHumanoidPromise")
	if NextHumanoidPromise then
		return NextHumanoidPromise
	end

	NextHumanoidPromise = Promise.new()
	local Connection = self.Humanoid.Changed:Connect(function(NewValue)
		if NewValue then
			NextHumanoidPromise:Resolve(NewValue)
		end
	end)

	NextHumanoidPromise:Finally(function()
		Connection:Disconnect()
	end)

	return self.Janitor:Add(NextHumanoidPromise, "Cancel", "NextHumanoidPromise")
end

--[=[
	Cleans up the humanoid tracker and sets the metatable to be nil.
]=]
function HumanoidTracker:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
end

function HumanoidTracker:__tostring()
	return "HumanoidTracker"
end

table.freeze(HumanoidTracker)
return HumanoidTracker
