--[=[
	@class IKRigUtility
]=]

local CharacterUtility = require(script.Parent.Parent.Parent.Utility.CharacterUtility)
local Math = require(script.Parent.Parent.Parent.Math.Math)
local Option = require(script.Parent.Parent.Parent.Parent.Option)

local IKRigUtility = {}

type Option<Value> = Option.Option<Value>

function IKRigUtility.GetTimeBeforeNextUpdate(Distance: number)
	if Distance < 128 then
		return 0
	elseif Distance < 256 then
		return 0.5 * Math.Map(Distance, 128, 256, 0, 1)
	else
		return 0.5
	end
end

function IKRigUtility.GetPlayerIKRig(Binder, Player: Player): Option<any>
	assert(Binder, "Bad Binder.")
	return CharacterUtility.GetPlayerHumanoid(Player):Then(function(Humanoid: Humanoid)
		return Option.Wrap(Binder:Get(Humanoid))
	end)
end

function IKRigUtility.GetPlayerIKRigOptionless(Binder, Player: Player)
	assert(Binder, "Bad Binder.")
	return CharacterUtility.GetPlayerHumanoid(Player):Then(function(Humanoid: Humanoid)
		return Option.Wrap(Binder:Get(Humanoid))
	end):Unwrap()
end

table.freeze(IKRigUtility)
return IKRigUtility
