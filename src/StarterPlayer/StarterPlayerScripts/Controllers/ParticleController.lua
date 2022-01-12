--[=[
	Legacy code written by AxisAngles to simulate particles with Guis

	@client
	@class ParticleController
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Knit)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)
local GetService = require(ReplicatedStorage.Knit.Util.GetService)
local ScreenGuiProvider = require(ReplicatedStorage.Knit.Util.Additions.BaseScreenGuiProvider)

local ParticleController = Knit.CreateController({
	Name = "ParticleController";
})

--[=[
	@type Vector Vector2 | Vector3
	@within ParticleController
	A vector data type.
]=]

--[=[
	@type ParticleFunction string | (self: ParticleProperties, DeltaTime: number, WorldTime: number) -> ()
	@within ParticleController
	The function type for a particle. Passing a string will expect a function that exists in the table `ParticleFunctions`.
]=]

--[=[
	@type RemoveOnCollision boolean | string | (self: ParticleProperties, RaycastResult: RaycastResult) -> boolean
	@within ParticleController
	The RemoveOnCollision function type for a particle. Passing a string will expect a function that exists in the table `RemoveFunctions`, passing a boolean will make sure it always removes when collided with.
]=]

--[=[
	@interface ParticleProperties
	@within ParticleController
	.Position Vector3 -- The position of the particle.
	.Bloom Vector? -- The bloom of the particle. Defaults to `Vector2.zero`.
	.Color Color3? -- The color of the particle. Defaults to `Color3.new(1, 1, 1)`.
	.Function ParticleFunction? -- The function of the particle.
	.Global boolean? -- Whether or not the particle is global.
	.Gravity Vector3? -- The gravity of the particle. Defaults to `Vector3.zero`.
	.Lifetime number? -- The lifetime of the particle.
	.Occlusion boolean? -- Whether the particle is occluded.
	.RemoveOnCollision RemoveOnCollision? -- Whether or not the particle should be removed on collision.
	.Size Vector? -- The size of the particle. Defaults to `Vector2.new(0.2, 0.2)`.
	.Transparency number? -- The transparency of the particle. Defaults to `0.5`.
	.Velocity Vector3? -- The velocity of the particle. Defaults to `Vector3.zero`.
	.WindResistance number? -- The wind resistance of the particle.
]=]

ParticleController.ParticleFunctions = {}
ParticleController.RemoveFunctions = {}

--[=[
	@prop MaxParticles IntValue
	@within ParticleController
	The maximum amount of particles that can be created at once. Changing this will reallocate.
]=]
ParticleController.MaxParticles = Instance.new("IntValue")
ParticleController.MaxParticles.Value = 400

--[=[
	@prop ParticleCount int
	@within ParticleController
	The current amount of particles.
]=]
ParticleController.ParticleCount = 0
ParticleController.ParticleFrames = table.create(ParticleController.MaxParticles.Value)
ParticleController.Particles = {}

--[=[
	@prop WindSpeed NumberValue
	@within ParticleController
	The wind speed of the particles.
]=]
ParticleController.WindSpeed = Instance.new("NumberValue")
ParticleController.WindSpeed.Value = 10

local LocalPlayer = Players.LocalPlayer
local IProperties = Constants.TYPE_CHECKS.IParticleProperties

local function NewFrame(Name: string): Frame
	local Frame: Frame = Instance.new("Frame")
	Frame.Archivable = false
	Frame.BorderSizePixel = 0
	Frame.Name = Name
	return Frame
end

local Update

--[[**
	Removes a Particle from the ParticleEngine.
	@param [t:IProperties] Properties The particle you want to remove.
	@returns [t:void]
**--]]
function ParticleController:Remove(Properties)
	local TypeSuccess, TypeError = IProperties(Properties)
	if not TypeSuccess then
		error(TypeError, 2)
	end

	local Particles = self.Particles
	if Particles[Properties] then
		Particles[Properties] = nil
		self.ParticleCount -= 1
	end
end

local EMPTY_VECTOR2 = Vector2.new()
local EMPTY_VECTOR3 = Vector3.new()
local SIZE_VECTOR2 = Vector2.new(0.2, 0.2)
local WHITE_COLOR3 = Color3.new(1, 1, 1)

--[[
{
	Position = Vector3

	Optional:
	Bloom = Vector2
	Color = Color3
	Global = Bool
	Gravity = Vector3
	Lifetime = Number
	Occlusion = Bool
	Size = Vector2
	Transparency = Number
	Velocity = Vector3
	WindResistance = Number

	Function = function(Table ParticleProperties, Number dt, Number t)
	RemoveOnCollision = function(BasePart Hit, Vector3 Position)
}
--]]

--[[**
	Adds a Particle to the ParticleEngine. See the script to find the properties.
	@param [t:IParticle] Particle The particle you want to add.
	@returns [t:void]
**--]]
function ParticleController:Add(Properties)
	local TypeSuccess, TypeError = IProperties(Properties)
	if not TypeSuccess then
		error(TypeError, 2)
	end

	if self.Particles[Properties] then
		return
	end

	debug.profilebegin("ParticleEngineClient:Add")

	local Function = Properties.Function
	local RemoveOnCollision = Properties.RemoveOnCollision

	local FunctionIsString = type(Function) == "string"
	local RemoveOnCollisionIsString = type(RemoveOnCollision) == "string"

	if FunctionIsString then
		Properties.Function = assert(self.Functions[Function], string.format("Function %q doesn't exist.", Function))
	end

	if RemoveOnCollisionIsString then
		Properties.RemoveOnCollision = assert(self.Functions[RemoveOnCollision], string.format("Function %q doesn't exist.", RemoveOnCollision))
	end

	Properties.Position = Properties.Position or EMPTY_VECTOR3
	Properties.Velocity = Properties.Velocity or EMPTY_VECTOR3
	Properties.Size = Properties.Size or SIZE_VECTOR2
	Properties.Bloom = Properties.Bloom or EMPTY_VECTOR2
	Properties.Gravity = Properties.Gravity or EMPTY_VECTOR3
	Properties.Color = Properties.Color or WHITE_COLOR3
	Properties.Transparency = Properties.Transparency or 0.5

	if Properties.Global then
		local BackupFunction = Properties.Function
		local BackupRemoveOnCollision = Properties.RemoveOnCollision

		Properties.Global = nil
		Properties.Function = FunctionIsString and Function or nil
		Properties.RemoveOnCollision = RemoveOnCollisionIsString and RemoveOnCollision or RemoveOnCollision ~= nil and true or nil

		GetService.Default("ParticleService").ReplicateParticle:Fire(Properties)

		Properties.Function = BackupFunction
		Properties.RemoveOnCollision = BackupRemoveOnCollision
	end

	Properties.Lifetime = Properties.Lifetime and Properties.Lifetime + time()

	local Particles = self.Particles
	local ParticleCount = self.ParticleCount
	if ParticleCount > self.MaxParticles.Value then
		Particles[next(Particles)] = nil
	else
		self.ParticleCount = ParticleCount + 1
	end

	Particles[Properties] = Properties
	debug.profileend()
	return Properties
end

function ParticleController:RegisterFunction(FunctionName: string, Function)
	self.Functions[FunctionName] = Function
	return self
end

function ParticleController:KnitStart()
	GetService.Option("ParticleService"):Match({
		Some = function(ParticleService)
			self.ScreenGui = ScreenGuiProvider:Get("ParticlesGui")
			self.LastUpdateTime = time()

			ParticleService.ReplicateParticle:Connect(function(Properties)
				self:Add(Properties)
			end)

			for Index = 1, self.MaxParticles.Value do
				self.ParticleFrames[Index] = NewFrame("Particle")
			end

			self.MaxParticles.Changed:Connect(function(NewValue)
				NewValue = math.clamp(NewValue, 100, 3000)
				for _, ParticleFrame in ipairs(self.ParticleFrames) do
					ParticleFrame:Destroy()
				end

				self.ParticleFrames = table.create(NewValue)
				local ParticleFrames = self.ParticleFrames
				for Index = 1, NewValue do
					ParticleFrames[Index] = NewFrame("Particle")
				end
			end)

			RunService.Heartbeat:Connect(function()
				debug.profilebegin("ParticleEngineUpdate")
				Update(self)
				debug.profileend()
			end)
		end;

		None = function()
			warn("[ParticleController.KnitStart] - Couldn't get ParticleService!")
		end;
	})
end

local function ParticleWind(CurrentTime, Position)
	debug.profilebegin("ParticleWind")
	local XY, YZ, ZX = Position.X + Position.Y, Position.Y + Position.Z, Position.Z + Position.X

	-- stylua: ignore
	local Result = Vector3.new(
		(math.sin(YZ + CurrentTime * 2) + math.sin(YZ + CurrentTime)) / 2 + math.sin((YZ + CurrentTime) / 10) / 2,
		(math.sin(ZX + CurrentTime * 2) + math.sin(ZX + CurrentTime)) / 2 + math.sin((ZX + CurrentTime) / 10) / 2,
		(math.sin(XY + CurrentTime * 2) + math.sin(XY + CurrentTime)) / 2 + math.sin((XY + CurrentTime) / 10) / 2
	)

	debug.profileend()
	return Result
end

local UpdateParameters = RaycastParams.new()
UpdateParameters.FilterType = Enum.RaycastFilterType.Blacklist
UpdateParameters.IgnoreWater = true

local function UpdatePositionVelocity(self, Properties, DeltaTime, CurrentTime)
	debug.profilebegin("UpdatePositionVelocity")

	local Velocity = Properties.Velocity
	local Position = Properties.Position + Velocity * DeltaTime
	local WindResistance = Properties.WindResistance

	Properties.Position = Position

	local Wind
	if WindResistance then
		Wind = (ParticleWind(CurrentTime, Position) * self.WindSpeed.Value - Velocity) * WindResistance
	else
		Wind = EMPTY_VECTOR3
	end

	Properties.Velocity = Velocity + (Properties.Gravity + Wind) * DeltaTime
	debug.profileend()
end

local function UpdateParticle(self, Particle, CurrentTime, DeltaTime)
	debug.profilebegin("UpdateParticle")
	if Particle.Lifetime - CurrentTime <= 0 then
		debug.profileend()
		return false
	end

	if type(Particle.Function) == "function" then
		debug.profilebegin("UpdateParticle.Function")
		Particle:Function(DeltaTime, CurrentTime)
		debug.profileend()
	end

	local LastPosition = Particle.Position
	UpdatePositionVelocity(self, Particle, DeltaTime, CurrentTime)

	if not Particle.RemoveOnCollision then
		debug.profileend()
		return true
	end

	local Displacement: Vector3 = Particle.Position - LastPosition
	local Distance = Displacement.Magnitude
	if Distance > 999 then
		Displacement *= (999 / Distance)
	end

	debug.profilebegin("UpdateParticle.Raycast")
	UpdateParameters.FilterDescendantsInstances = table.create(1, LocalPlayer.Character)
	local RaycastResult = Workspace:Raycast(LastPosition, Displacement, UpdateParameters)
	debug.profileend()

	if not RaycastResult or not RaycastResult.Instance then
		debug.profileend()
		return true
	end

	if type(Particle.RemoveOnCollision) == "function" then
		debug.profilebegin("UpdateParticle.RemoveOnCollision")
		local RemoveOnCollision = Particle:RemoveOnCollision(RaycastResult)
		debug.profileend()

		if not RemoveOnCollision then
			debug.profileend()
			return false
		end
	else
		debug.profileend()
		return false
	end

	debug.profileend()
	return true
end

local function UpdateScreenInfo(self, CurrentCamera)
	debug.profilebegin("UpdateScreenInfo")
	local AbsoluteSize = self.ScreenGui.AbsoluteSize
	local ScreenSizeX = AbsoluteSize.X
	local ScreenSizeY = AbsoluteSize.Y
	local PlaneSizeY = 2 * math.tan(CurrentCamera.FieldOfView * 0.0087266462599716)

	self.ScreenSizeX = ScreenSizeX
	self.ScreenSizeY = ScreenSizeY
	self.PlaneSizeY = PlaneSizeY
	self.PlaneSizeX = PlaneSizeY * ScreenSizeX / ScreenSizeY
	debug.profileend()
end

local function ParticleRender(self, CameraPosition, CameraInverse, Frame, Particle)
	debug.profilebegin("ParticleRender")
	local RealPosition = CameraInverse * Particle.Position
	local LastScreenPosition = Particle.LastScreenPosition

	local ScreenSizeX = self.ScreenSizeX
	local ScreenSizeY = self.ScreenSizeY
	local PlaneSizeX = self.PlaneSizeX
	local PlaneSizeY = self.PlaneSizeY

	if not (RealPosition.Z < -1 and LastScreenPosition) then
		if RealPosition.Z > 0 then
			Particle.LastScreenPosition = nil
		else
			local ScreenPosition = RealPosition / RealPosition.Z
			Particle.LastScreenPosition = Vector2.new((0.5 - ScreenPosition.X / PlaneSizeX) * ScreenSizeX, (0.5 + ScreenPosition.Y / PlaneSizeY) * ScreenSizeY)
		end

		debug.profileend()
		return false
	end

	local RealPositionZ = RealPosition.Z
	local ScreenPosition = RealPosition / RealPositionZ
	local Bloom = Particle.Bloom
	local Transparency = Particle.Transparency

	local PositionX = (0.5 - ScreenPosition.X / PlaneSizeX) * ScreenSizeX
	local PositionY = (0.5 + ScreenPosition.Y / PlaneSizeY) * ScreenSizeY

	local PreSizeY = -Particle.Size.Y / RealPositionZ * ScreenSizeY / PlaneSizeY
	local SizeX = -Particle.Size.X / RealPositionZ * ScreenSizeY / PlaneSizeY + Bloom.X

	local RealPositionX, RealPositionY = PositionX - LastScreenPosition.X, PositionY - LastScreenPosition.Y
	local SizeY = PreSizeY + math.sqrt(RealPositionX * RealPositionX + RealPositionY * RealPositionY) + Bloom.Y

	Particle.LastScreenPosition = Vector2.new(PositionX, PositionY)

	if Particle.Occlusion then
		local Position: Vector3 = Particle.Position - CameraPosition
		local Magnitude = Position.Magnitude
		if Magnitude > 999 then
			Position *= (999 / Magnitude)
		end

		debug.profilebegin("ParticleRender.FilterDescendantsInstances")
		UpdateParameters.FilterDescendantsInstances = table.create(1, LocalPlayer.Character)
		debug.profileend()

		debug.profilebegin("ParticleRender.Raycast")
		local RaycastResult = Workspace:Raycast(CameraPosition, Position, UpdateParameters)
		debug.profileend()

		if RaycastResult then
			debug.profileend()
			return false
		end
	end

	debug.profilebegin("ParticleRender.SetProperties")
	Frame.Position = UDim2.fromOffset((PositionX + LastScreenPosition.X - SizeX) / 2, (PositionY + LastScreenPosition.Y - SizeY) / 2)

	Frame.Size = UDim2.fromOffset(SizeX, SizeY)
	Frame.Rotation = 90 + math.atan2(RealPositionY, RealPositionX) * 57.295779513082
	Frame.BackgroundColor3 = Particle.Color
	Frame.BackgroundTransparency = Transparency + (1 - Transparency) * (1 - PreSizeY / SizeY)
	debug.profileend()

	debug.profileend()
	return true
end

local function UpdateRender(self)
	debug.profilebegin("UpdateRender")
	local CurrentCamera = Workspace.CurrentCamera
	UpdateScreenInfo(self, CurrentCamera)

	local CameraCFrame = CurrentCamera.CFrame
	local CameraInverse = CameraCFrame:Inverse()
	local CameraPosition = CameraCFrame.Position

	local ParticleFrames = self.ParticleFrames
	local ScreenGui = self.ScreenGui

	local FrameIndex, Frame = next(ParticleFrames)
	for Particle in next, self.Particles do
		if ParticleRender(self, CameraPosition, CameraInverse, Frame, Particle) then
			Frame.Parent = ScreenGui
			FrameIndex, Frame = next(ParticleFrames, FrameIndex)
		end
	end

	while FrameIndex and Frame.Parent do
		Frame.Parent = nil
		FrameIndex, Frame = next(ParticleFrames, FrameIndex)
	end

	debug.profileend()
end

function Update(self)
	local CurrentTime = time()
	local DeltaTime = CurrentTime - self.LastUpdateTime
	self.LastUpdateTime = CurrentTime

	local ToRemove = {}
	for Particle in next, self.Particles do
		if not UpdateParticle(self, Particle, CurrentTime, DeltaTime) then
			ToRemove[Particle] = true
		end
	end

	for Particle in next, ToRemove do
		self:Remove(Particle)
	end

	UpdateRender(self)
end

return ParticleController
