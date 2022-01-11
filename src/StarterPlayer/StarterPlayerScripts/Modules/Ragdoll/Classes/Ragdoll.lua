--[=[
	Client side ragdolling meant to be used with a binder. See [RagdollBindersClient].
	While a humanoid is bound with this class, it is ragdolled.

	@client
	@class RagdollClient
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local CharacterUtility = require(ReplicatedStorage.Knit.Util.Additions.Utility.CharacterUtility)
local GetController = require(ReplicatedStorage.Knit.Util.GetController)

local RagdollClient = setmetatable({}, BaseObject)
RagdollClient.ClassName = "RagdollClient"
RagdollClient.__index = RagdollClient

--[=[
	Constructs a new RagdollClient. Should be done via [Binder]. See [RagdollBindersClient].
	@param humanoid Humanoid
	@return RagdollClient
]=]
function RagdollClient.new(Humanoid: Humanoid)
	local self = setmetatable(BaseObject.new(Humanoid), RagdollClient)
	self.CameraStackController = GetController("CameraStackController")

	CharacterUtility.GetPlayerFromCharacter(self.Object):Match({
		None = function() end;
		Some = function(Player: Player)
			if Player == Players.LocalPlayer then
				self:SetupHapticFeedback()
				self:SetupCameraShake(self.CameraStackController:GetImpulseCamera())
			end
		end;
	})

	return self
end

-- TODO: Move out of this open source module
function RagdollClient:SetupCameraShake(ImpulseCamera)
	local Head = self.Object.Parent:FindFirstChild("Head")
	if not Head then
		return
	end

	local LastVelocity = Head.AssemblyLinearVelocity
	self.Janitor:Add(RunService.RenderStepped:Connect(function()
		local CameraCFrame = Workspace.CurrentCamera.CFrame
		local AssemblyLinearVelocity = Head.AssemblyLinearVelocity
		local DeltaVelocity = AssemblyLinearVelocity - LastVelocity
		if DeltaVelocity.Magnitude >= 0 then
			ImpulseCamera:Impulse(CameraCFrame:VectorToObjectSpace(-0.1 * CameraCFrame.LookVector:Cross(DeltaVelocity)))
		end

		LastVelocity = AssemblyLinearVelocity
	end), "Disconnect")
end

function RagdollClient:SetupHapticFeedback()
	local LastInputType = UserInputService:GetLastInputType()
	GetController.Option("HapticFeedbackController"):Match({
		None = function()
			warn("[RagdollClient.SetupHapticFeedback] - Couldn't get HapticFeedbackController!")
		end;

		Some = function(HapticFeedbackController)
			if not HapticFeedbackController:SetSmallVibration(LastInputType, 1) then
				return
			end

			local Alive = true
			self.Janitor:Add(function()
				Alive = false
			end, true)

			task.defer(function()
				for Index = 1, 0, -0.1 do
					HapticFeedbackController:SetSmallVibration(LastInputType, Index)
					task.wait(0.05)
				end

				HapticFeedbackController:SetSmallVibration(LastInputType, 0)
				if Alive then
					self.Janitor:Add(function()
						HapticFeedbackController:SmallVibrate(LastInputType)
					end, true)
				end
			end)
		end;
	})
end

function RagdollClient:__tostring()
	return "Ragdoll"
end

table.freeze(RagdollClient)
return RagdollClient
