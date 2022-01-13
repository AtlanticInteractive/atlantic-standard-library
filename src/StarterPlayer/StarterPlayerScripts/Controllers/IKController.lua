--[=[
	Handles IK for local client.

	@client
	@class IKController
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local IKBinders = require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("IK"):WaitForChild("IKBinders"))
local IKRigUtility = require(ReplicatedStorage.Knit.Util.Additions.IK.Rig.IKRigUtility)
local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local Option = require(ReplicatedStorage.Knit.Util.Option)

local IKController = Knit.CreateController({
	Name = "IKController";
})

IKController.LookAround = true

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param Humanoid Humanoid
	@return IKRigClient?
]=]
function IKController:GetRig(Humanoid: Humanoid)
	assert(typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid"), "Bad humanoid")
	return self.IkBinders.IKRig:Get(Humanoid)
end

--[=[
	Retrieves an IKRig. Binds the rig if it isn't already bound.
	@param Humanoid Humanoid
	@return Promise<IKRigClient>
]=]
function IKController:PromiseRig(Humanoid: Humanoid)
	assert(typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid"), "Bad humanoid")
	return self.IkBinders.IKRig:Promise(Humanoid)
end

--[=[
	Exposed API for guns and other things to start setting aim position
	which will override for a limited time.

	```lua
	-- Make the local character always look towards the origin

	local IKController = require("IKController")
	local IKAimPositionPriorities = require("IKAimPositionPriorities")

	RunService.Stepped:Connect(function()
		serviceBag:GetService(IKController):SetAimPosition(Vector3.new(0, 0, 0), IKAimPositionPriorities.HIGH)
	end)
	```

	@param Position Vector3? -- May be nil to set no position
	@param OptionalPriority number?
]=]
function IKController:SetAimPosition(Position: Vector3?, OptionalPriority: number?)
	if Position ~= Position then
		return warn("[IKController.SetAimPosition] - position is NaN")
	end

	self:GetLocalAimer():Match({
		None = function() end;
		Some = function(Aimer)
			Aimer:SetAimPosition(Position, OptionalPriority)
		end;
	})
end

--[=[
	If true, tells the local player to look around at whatever
	the camera is pointed at.

	```lua

	serviceBag:GetService(require("IKController")):SetLookAround(false)
	```

	@param LookAround boolean
]=]
function IKController:SetLookAround(LookAround: boolean)
	self.LookAround = LookAround
end

--[=[
	Retrieves the local aimer for the local player.

	@return Option<IKRigAimerLocalPlayer>
]=]
function IKController:GetLocalAimer()
	return self:GetLocalPlayerRig():Then(function(Rig)
		return Option.Wrap(Rig:GetLocalPlayerAimer())
	end)
end

--[=[
	Attempts to retrieve the local player's ik rig, if it exists.

	@return Option<IKRigClient>
]=]
function IKController:GetLocalPlayerRig()
	return IKRigUtility.GetPlayerIKRig(assert(self.IkBinders.IKRig, "Not initialize"), Players.LocalPlayer)
end

function IKController:KnitStart()
	self.IkBinders:Start()

	local function OnStepped()
		debug.profilebegin("IKUpdate")
		self:GetLocalAimer():Match({
			None = function() end;
			Some = function(LocalAimer)
				LocalAimer:SetLookAround(self.LookAround)
				LocalAimer:UpdateStepped()
			end;
		})

		local CameraPosition = Workspace.CurrentCamera.CFrame.Position

		for _, Rig in ipairs(self.IkBinders.IKRig:GetAll()) do
			debug.profilebegin("RigUpdate")

			local Position = Rig:GetPositionOrNil()

			if Position then
				local LastUpdateTime = Rig:GetLastUpdateTime()
				local Distance = (CameraPosition - Position).Magnitude
				local TimeBeforeNextUpdate = IKRigUtility.GetTimeBeforeNextUpdate(Distance)

				if os.clock() - LastUpdateTime >= TimeBeforeNextUpdate then
					Rig:Update() -- Update actual rig
				else
					Rig:UpdateTransformOnly()
				end
			end

			debug.profileend()
		end

		debug.profileend()
	end

	self.Janitor:Add(RunService.Stepped:Connect(OnStepped), "Disconnect")
end

function IKController:KnitInit()
	self.Janitor = Janitor.new()
	self.LookAround = true
	self.IkBinders = IKBinders:Initialize()
end

return IKController
