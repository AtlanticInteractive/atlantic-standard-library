local t = require(script.Parent.Vendor.t)

local OptionalVector = t.optional(t.union(t.Vector2, t.Vector3))

local KnitConstants = {
	IK_CONSTANTS = {
		REMOTE_EVENT_NAME = "IKRigRemoteEvent";
	};

	RAGDOLL_CONSTANTS = {
		IS_MOTOR_ANIMATED_NAME = "IsMotorAnimated";
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
