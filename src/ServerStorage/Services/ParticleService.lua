local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Knit)
local Constants = require(ReplicatedStorage.Knit.Util.Additions.KnitConstants)

local ParticleService = Knit.CreateService({
	Client = {};
	Name = "ParticleService";
})

ParticleService.Client.ReplicateParticle = Knit.CreateSignal()

local IProperties = Constants.TYPE_CHECKS.IParticleProperties

local DEFAULT_SIZE = Vector2.new(0.2, 0.2)
local EMPTY_VECTOR2 = Vector2.new()
local EMPTY_VECTOR3 = Vector3.new()
local WHITE_COLOR3 = Color3.new(1, 1, 1)

function ParticleService:Add(Properties)
	local TypeSuccess, TypeError = IProperties(Properties)
	if not TypeSuccess then
		error(TypeError, 2)
	end

	Properties.Velocity = Properties.Velocity or EMPTY_VECTOR3
	Properties.Size = Properties.Size or DEFAULT_SIZE
	Properties.Bloom = Properties.Bloom or EMPTY_VECTOR2
	Properties.Gravity = Properties.Gravity or EMPTY_VECTOR3
	Properties.Color = Properties.Color or WHITE_COLOR3
	Properties.Transparency = Properties.Transparency or 0.5

	self.Client.ReplicateParticle:FireAll(Properties)
	return Properties
end

function ParticleService:KnitInit()
	self.Client.ReplicateParticle:Connect(function(Player: Player, Properties)
		Properties.Global = nil
		self.Client.ReplicateParticle:FireFilter(function(CurrentPlayer: Player)
			return CurrentPlayer ~= Player
		end, Properties)
	end)
end

return ParticleService
