--[=[
	Handles particle replication on the server side

	@server
	@class ParticleService
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)

local ParticleService = Knit.CreateService({
	Client = {};
	Name = "ParticleService";
})

--[=[
	@type Vector Vector2 | Vector3
	@within ParticleService
	A vector data type.
]=]

--[=[
	@interface ParticleProperties
	@within ParticleService
	.Position Vector3 -- The position of the particle.
	.Bloom Vector? -- The bloom of the particle. Defaults to `Vector2.zero`.
	.Color Color3? -- The color of the particle. Defaults to `Color3.new(1, 1, 1)`.
	.Function string? -- The function of the particle.
	.Gravity Vector3? -- The gravity of the particle. Defaults to `Vector3.zero`.
	.Lifetime number? -- The lifetime of the particle.
	.Occlusion boolean? -- Whether the particle is occluded.
	.RemoveOnCollision boolean? -- Whether or not the particle should be removed on collision.
	.Size Vector? -- The size of the particle. Defaults to `Vector2.new(0.2, 0.2)`.
	.Transparency number? -- The transparency of the particle. Defaults to `0.5`.
	.Velocity Vector3? -- The velocity of the particle. Defaults to `Vector3.zero`.
	.WindResistance number? -- The wind resistance of the particle.
]=]

--[=[
	@prop ReplicateParticle RemoteSignal<ParticleProperties>
	@tag Client
	@within ParticleService
	Used to replicate a particle globally. Might be wise to disable this.
]=]
ParticleService.Client.ReplicateParticle = Knit.CreateSignal()

local IProperties = Constants.TYPE_CHECKS.IParticleProperties
type ParticleProperties = Constants.ParticleProperties

local DEFAULT_SIZE = Vector2.new(0.2, 0.2)
local EMPTY_VECTOR2 = Vector2.new()
local EMPTY_VECTOR3 = Vector3.new()
local WHITE_COLOR3 = Color3.new(1, 1, 1)

--[=[
	Adds a particle to every player.
	@param Properties ParticleProperties -- The properties of the particle.
	@returns ParticleProperties
]=]
function ParticleService:Add(Properties: ParticleProperties)
	local TypeSuccess, TypeError = IProperties(Properties)
	if not TypeSuccess then
		error(TypeError, 2)
	end

	Properties.Bloom = Properties.Bloom or EMPTY_VECTOR2
	Properties.Color = Properties.Color or WHITE_COLOR3
	Properties.Gravity = Properties.Gravity or EMPTY_VECTOR3
	Properties.Size = Properties.Size or DEFAULT_SIZE
	Properties.Transparency = Properties.Transparency or 0.5
	Properties.Velocity = Properties.Velocity or EMPTY_VECTOR3

	self.Client.ReplicateParticle:FireAll(Properties)
	return Properties
end

function ParticleService:KnitInit()
	local ReplicateParticle = self.Client.ReplicateParticle

	ReplicateParticle:Connect(function(Player: Player, Properties)
		Properties.Global = nil
		ReplicateParticle:FireFilter(function(CurrentPlayer: Player)
			return CurrentPlayer ~= Player
		end, Properties)
	end)
end

return ParticleService
