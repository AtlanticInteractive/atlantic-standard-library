--[=[
	@class LocalizationServiceUtility
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")
local Promise = require(ReplicatedStorage.Knit.Util.Promise)

local ERROR_PUBLISH_REQUIRED = "Publishing the game is required to use GetTranslatorForPlayerAsync API."

local LocalizationServiceUtility = {}

function LocalizationServiceUtility.PromiseTranslator(Player: Player)
	local Timeout = 20
	if RunService:IsStudio() then
		Timeout = 0.5
	end

	local AsyncTranslatorPromise = Promise.Defer(function(Resolve, Reject, OnCancel)
		if OnCancel(function() end) then
			return
		end

		local Translator = nil
		local Success, Error = pcall(function()
			Translator = LocalizationService:GetTranslatorForPlayerAsync(Player)
		end)

		if not Success then
			Reject(Error or "Failed to GetTranslatorForPlayerAsync")
		elseif Translator then
			assert(typeof(Translator) == "Instance", "Bad translator")
			Resolve(Translator)
		else
			Reject("Translator was not returned")
		end
	end)

	AsyncTranslatorPromise:Timeout(Timeout, string.format("GetTranslatorForPlayerAsync is still pending after %f, using local table", Timeout))

	return AsyncTranslatorPromise:Catch(function(Error)
		if Error ~= ERROR_PUBLISH_REQUIRED then
			warn(string.format("[LocalizationServiceUtility.PromiseTranslator] - %s", tostring(Error)))
		end

		return LocalizationService:GetTranslatorForPlayer(Player)
	end)
end

table.freeze(LocalizationServiceUtility)
return LocalizationServiceUtility
