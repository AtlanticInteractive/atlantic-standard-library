--[=[
	Utility methods for ragdolling. See [Ragdoll] and [RagdollClient] which call into this class.
	If you want to make ragdolls without binders, this class may work for you.

	@class RagdollUtils
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CharacterUtility = require(script.Parent.Parent.Utility.CharacterUtility)
local Constants = require(script.Parent.Parent.KnitConstants)
local Janitor = require(script.Parent.Parent.Parent.Janitor)
local PromiseChild = require(script.Parent.Parent.Promises.PromiseChild)
local RagdollRigging = require(script.Parent.RagdollRigging)
local RxValueBaseUtility = require(script.Parent.Parent.Vendor.Nevermore.RxValueBaseUtility)

local RagdollUtility = {}

local NoOp = function() end

local RagdollConstants = Constants.RAGDOLL_CONSTANTS

--[=[
	Sets up state monitoring for when the humanoid changes to ensure ragdoll is smooth.

	@param Humanoid Humanoid
	@return Janitor
]=]
function RagdollUtility.SetupState(Humanoid: Humanoid)
	local StateJanitor = Janitor.new()

	local function UpdateState()
		-- If we change state to dead then it'll flicker back and forth firing off
		-- the dead event multiple times.

		if Humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end

	local function TeleportRootPartToUpperTorso()
		-- This prevents clipping into the ground, mostly, at least on R15, on thin parts
		local DoReturn = false
		CharacterUtility.GetPlayerFromCharacter(Humanoid):Match({
			None = function()
				DoReturn = true
			end;

			Some = function(Player: Player)
				DoReturn = Player ~= Players.LocalPlayer
			end;
		})

		if DoReturn then
			return
		end

		local RootPart = Humanoid.RootPart
		if not RootPart then
			return
		end

		local Character = Humanoid.Parent
		if not Character then
			return
		end

		local UpperTorso = Character:FindFirstChild("UpperTorso")
		if not UpperTorso then
			return
		end

		RootPart.CFrame = UpperTorso.CFrame
	end

	StateJanitor:Add(function()
		StateJanitor:Cleanup() -- GC other events
		TeleportRootPartToUpperTorso()
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end, true)

	StateJanitor:Add(Humanoid.StateChanged:Connect(UpdateState), "Disconnect")
	UpdateState()
	return StateJanitor
end

--[=[
	Prevents animations from being applied on the humanoid torso on both
	the server and client.

	:::note
	We need this on all clients/servers to override animations!
	:::

	@param humanoid Humanoid
	@return Janitor
]=]
function RagdollUtility.PreventAnimationTransformLoop(Humanoid: Humanoid)
	local PreventJanitor = Janitor.new()

	local Character = Humanoid.Parent
	if not Character then
		warn("[RagdollUtils.preventAnimationTransformLoop] - No character")
		return PreventJanitor
	end

	PreventJanitor:AddPromise(PromiseChild(Humanoid.Parent, "LowerTorso")):Then(function(LowerTorso)
		return PromiseChild(LowerTorso, "Root")
	end):Then(function(Root)
		local LastTransform = Root.Transform

		PreventJanitor:Add(RunService.Stepped:Connect(function()
			Root.Transform = LastTransform
		end), "Disconnect")
	end)

	return PreventJanitor
end

--[=[
	Sets up the motors so that ragdoll can go, applying velocities to the ragdoll.
	This needs to occur on the network owner of the character first.

	@param humanoid Humanoid
	@return Janitor
]=]
function RagdollUtility.SetupMotors(Humanoid: Humanoid)
	local Character = Humanoid.Parent
	local RigType = Humanoid.RigType

	-- We first disable the motors on the network owner (the player that owns this character).
	--
	-- This way there is no visible round trip hitch. By the time the server receives the joint
	-- break physics data for the child parts should already be available. Seamless transition.
	--
	-- If we initiated ragdoll by disabling joints on the server there's a visible hitch while the
	-- server waits at least a full round trip time for the network owner to receive the joint
	-- removal, start simulating the ragdoll, and replicate physics data. Meanwhile the other body
	-- parts would be frozen in air on the server and other clients until physics data arives from
	-- the owner. The ragdolled player wouldn't see it, but other players would.
	--
	-- We also specifically do not disable the root joint on the client so we can maintain a
	-- consistent mechanism and network ownership unit root. If we did disable the root joint we'd
	-- be creating a new, seperate network ownership unit that we would have to wait for the server
	-- to assign us network ownership of before we would start simulating and replicating physics
	-- data for it, creating an additional round trip hitch on our end for our own character.
	local Motors = RagdollRigging.GetMotors(Character, RigType)

	local SetupJanitor = Janitor.new()

	local function UpdateMotor(Motor)
		if Motor:GetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_NAME) then
			Motor.Enabled = true
		else
			Motor.Enabled = false
		end
	end

	-- Disable all regular joints:
	for _, Motor in ipairs(Motors) do
		SetupJanitor:Add(Motor:GetAttributeChangedSignal(RagdollConstants.IS_MOTOR_ANIMATED_NAME):Connect(function()
			UpdateMotor(Motor)
		end), "Disconnect")

		UpdateMotor(Motor)
		SetupJanitor:Add(function()
			Motor.Enabled = true
		end, true)
	end

	-- Set the root part to non-collide
	local RootPart = Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		RootPart.CanCollide = false
	end

	local Head = Character:FindFirstChild("Head")
	if Head and Head:IsA("BasePart") then
		Head.CanCollide = true
	end

	-- Apply velocities from animation to the child parts to mantain visual momentum.
	--
	-- This should be done on the network owner's side just after disabling the kinematic joint so
	-- the child parts are split off as seperate dynamic bodies. For consistent animation times and
	-- visual momentum we want to do this on the machine that controls animation state for the
	-- character and will be simulating the ragdoll, in this case the client.
	--
	-- It's also important that this is called *before* any animations are canceled or changed after
	-- death! Otherwise there will be no animations to get velocities from or the velocities won't
	-- be consistent!
	local Animator = Humanoid:FindFirstChildWhichIsA("Animator")
	if Animator then
		Animator:ApplyJointVelocities(Motors)
	end

	return SetupJanitor
end

--[=[
	If the head is not a mesh part, this resizes the head into a mesh part with correct
	physics, and ensures the head scaling is correct.

	@param humanoid Humanoid
	@return JanitorTask
]=]
function RagdollUtility.SetupHead(Humanoid: Humanoid)
	local Model = Humanoid.Parent
	if not Model then
		return NoOp
	end

	local Head = Model:FindFirstChild("Head")
	if not Head then
		return NoOp
	end

	if Head:IsA("MeshPart") then
		return NoOp
	end

	local OriginalSizeValue = Head:FindFirstChild("OriginalSize")
	if not OriginalSizeValue then
		return NoOp
	end

	local SpecialMesh = Head:FindFirstChildWhichIsA("SpecialMesh")
	if not SpecialMesh then
		return NoOp
	end

	if SpecialMesh.MeshType ~= Enum.MeshType.Head then
		return NoOp
	end

	-- More accurate physics for heads! Heads start at 2,1,1 (at least they used to)
	local SetupJanitor = Janitor.new()
	local LastHeadScale

	SetupJanitor:Add(RxValueBaseUtility.ObserveBrio(Humanoid, "NumberValue", "HeadScale"):Subscribe(function(HeadScaleBrio)
		if HeadScaleBrio:IsDead() then
			return
		end

		local HeadScale = HeadScaleBrio:GetValue()
		LastHeadScale = HeadScale
		Head.Size = Vector3.new(1, 1, 1) * HeadScale
	end), "Destroy")

	-- Cleanup and reset head scale
	SetupJanitor:Add(function()
		if LastHeadScale then
			Head.Size = OriginalSizeValue.Value * LastHeadScale
		end
	end, true)

	return SetupJanitor
end

table.freeze(RagdollUtility)
return RagdollUtility
