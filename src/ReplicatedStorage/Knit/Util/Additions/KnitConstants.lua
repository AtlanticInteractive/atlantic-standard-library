local t = require(script.Parent.Vendor.t)
local OptionalVector = t.optional(t.union(t.Vector2, t.Vector3))

type VectorType = Vector2 | Vector3

export type ParticleProperties = {
	Position: Vector3,

	-- Optional
	Bloom: VectorType?,
	Color: Color3?,
	Global: boolean?,
	Gravity: Vector3?,
	Lifetime: number?,
	Occlusion: boolean?,
	Size: VectorType?,
	Transparency: number?,
	Velocity: Vector3?,
	WindResistance: number?,

	Function: ParticleFunctionOrString?,
	RemoveOnCollision: RemoveOnCollisionOrStringOrTrue?,
}

export type ParticleFunction = (self: ParticleProperties, DeltaTime: number, WorldTime: number) -> boolean
export type RemoveOnCollision = (self: ParticleProperties, RaycastResult: RaycastResult) -> boolean
export type ParticleFunctionOrString = ParticleFunction | string
export type RemoveOnCollisionOrStringOrTrue = RemoveOnCollision | string | boolean

local KnitConstants = {
	COOLDOWN_CONSTANTS = {
		COOLDOWN_START_TIME_ATTRIBUTE = "CooldownStartTime";
		COOLDOWN_TIME_NAME = "CooldownTime";
	};

	IK_CONSTANTS = {
		REMOTE_EVENT_NAME = "IKRigRemoteEvent";
	};

	RAGDOLL_CONSTANTS = {
		IS_MOTOR_ANIMATED_NAME = "IsMotorAnimated";
		REMOTE_EVENT_NAME = "RagdollRemoteEvent";
	};

	TYPE_CHECKS = {
		IParticleProperties = t.interface({
			Position = t.Vector3;
			Bloom = OptionalVector;
			Color = t.optional(t.Color3);
			Function = t.optional(t.union(t.callback, t.string));
			Global = t.optional(t.boolean);
			Gravity = t.optional(t.Vector3);
			Lifetime = t.optional(t.number);
			Occlusion = t.optional(t.boolean);
			RemoveOnCollision = t.optional(t.union(t.callback, t.boolean, t.string));
			Size = OptionalVector;
			Transparency = t.optional(t.number);
			Velocity = t.optional(t.Vector3);
			WindResistance = t.optional(t.number);
		});
	};
}

table.freeze(KnitConstants)
return KnitConstants
