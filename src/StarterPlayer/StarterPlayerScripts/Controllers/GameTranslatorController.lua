local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Knit = require(ReplicatedStorage.Knit)
local JsonTranslator = require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("Classes"):WaitForChild("JsonTranslator"))

local GameTranslatorController = Knit.CreateController({
	Name = "GameTranslatorController";
})

function GameTranslatorController:ObserveFormatByKey(Key: string, Arguments)
	return self.GameTranslator:ObserveFormatByKey(Key, Arguments)
end

function GameTranslatorController:FormatByKey(Key: string, Arguments)
	return self.GameTranslator:FormatByKey(Key, Arguments)
end

function GameTranslatorController:PromiseFormatByKey(Key: string, Arguments)
	return self.GameTranslator:PromiseFormatByKey(Key, Arguments)
end

function GameTranslatorController:KnitInit()
	self.GameTranslator = JsonTranslator.new("en", {
		Actions = {};
	})
end

return GameTranslatorController
