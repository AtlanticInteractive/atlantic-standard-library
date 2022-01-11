-- Loader
-- Stephen Leitnick
-- January 10, 2021

--[[
	Loads all ModuleScripts within the given parent.

	Loader.LoadChildren(parent: Instance): module[]
	Loader.LoadDescendants(parent: Instance): module[]
--]]

local Loader = {}

function Loader.LoadChildren(Parent: Instance)
	local Modules = {}
	local Length = 0

	for _, Child in ipairs(Parent:GetChildren()) do
		if Child:IsA("ModuleScript") then
			if string.match(Child.Name, "%.disabled$") then
				continue
			end

			Length += 1
			Modules[Length] = require(Child)
		end
	end

	return Modules
end

function Loader.LoadDescendants(Parent: Instance)
	local Modules = {}
	local Length = 0

	for _, Child in ipairs(Parent:GetDescendants()) do
		if Child:IsA("ModuleScript") then
			if string.match(Child.Name, "%.disabled$") then
				continue
			end

			Length += 1
			Modules[Length] = require(Child)
		end
	end

	return Modules
end

table.freeze(Loader)
return Loader
