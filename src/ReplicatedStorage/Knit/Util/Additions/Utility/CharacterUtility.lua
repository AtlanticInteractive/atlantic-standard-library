--[=[
	General character related utilities.
	@class CharacterUtility
]=]

local Players = game:GetService("Players")
local Option = require(script.Parent.Parent.Parent.Option)

local CharacterUtility = {}

type Option<Value> = Option.Option<Value>

--[=[
	Gets a player's humanoid, if it exists.
	@param Player Player
	@return Option<Humanoid>
]=]
function CharacterUtility.GetPlayerHumanoid(Player: Player): Option<Humanoid>
	local Character = Player.Character
	if not Character then
		return Option.None
	end

	return Option.Wrap(Character:FindFirstChildOfClass("Humanoid"))
end

--[=[
	Gets a player's humanoid, and ensures it is alive.
	@param Player Player
	@return Option<Humanoid>
]=]
function CharacterUtility.GetAlivePlayerHumanoid(Player: Player): Option<Humanoid>
	return CharacterUtility.GetPlayerHumanoid(Player):Then(function(Humanoid: Humanoid)
		if Humanoid.Health <= 0 then
			return Option.None
		end

		return Option.Some(Humanoid)
	end)
end

--[=[
	Gets a player's humanoid.RootPart, and ensures the humanoid is alive.
	@param Player Player
	@return Option<BasePart>
]=]
function CharacterUtility.GetAlivePlayerRootPart(Player: Player): Option<BasePart>
	return CharacterUtility.GetPlayerHumanoid(Player):Then(function(Humanoid: Humanoid)
		if Humanoid.Health <= 0 then
			return Option.None
		end

		return Option.Wrap(Humanoid.RootPart)
	end)
end

--[=[
	Gets a player's humanoid.RootPart.
	@param Player Player
	@return Option<BasePart>
]=]
function CharacterUtility.GetPlayerRootPart(Player: Player): Option<BasePart>
	return CharacterUtility.GetPlayerHumanoid(Player):Then(function(Humanoid: Humanoid)
		return Option.Wrap(Humanoid.RootPart)
	end)
end

local UNEQUIP_MATCH = {
	Some = function(Humanoid: Humanoid)
		Humanoid:UnequipTools()
	end;

	None = function() end;
}

--[=[
	Unequips all tools for a give player's humanoid, if the humanoid exists.

	```lua
	local Players = game:GetService("Players")
	for _, Player in ipairs(Players:GetPlayers()) do
		CharacterUtility.UnequipTools(Player)
	end
	```

	@param Player Player
]=]
function CharacterUtility.UnequipTools(Player)
	CharacterUtility.GetPlayerHumanoid(Player):Match(UNEQUIP_MATCH)
end

--[=[
	Returns the player that a descendent is part of, if it is part of one.

	```lua
	script.Parent.Touched:Connect(function(Hit)
		CharacterUtility.GetPlayerFromCharacter(Hit):Match({
			Some = function(Player: Player)
				-- Activate button!
			end;

			None = function() end;
		})
	end)
	```

	:::tip
	This method is useful in a ton of different situations. For example, you can
	use it on classes bound to a humanoid, to determine the player. You can also
	use it to determine, upon touched events, if a part is part of a character.
	:::

	@param Descendant Instance -- A child of the potential character.
	@return Option<Player>
]=]
function CharacterUtility.GetPlayerFromCharacter(Descendant: Instance): Option<Player>
	local Character = Descendant
	local Player = Players:GetPlayerFromCharacter(Character)

	while not Player do
		if Character.Parent then
			Character = Character.Parent
			Player = Players:GetPlayerFromCharacter(Character)
		else
			return Option.None
		end
	end

	return Option.Wrap(Player)
end

table.freeze(CharacterUtility)
return CharacterUtility
