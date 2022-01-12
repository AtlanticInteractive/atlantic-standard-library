--[=[
	Utility function that loads a translator from a folder or a table.
	@class JsonTranslator
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Knit.Util.Janitor)
local JsonToLocalizationTable = require(ReplicatedStorage.Knit.Util.Additions.Utility.JsonToLocalizationTable)
local LocalizationServiceUtility = require(StarterPlayerScripts:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("LocalizationServiceUtility"))
local Observable = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.Observable)
local Promise = require(ReplicatedStorage.Knit.Util.Promise)
local PseudoLocalize = require(ReplicatedStorage.Knit.Util.Additions.Utility.PseudoLocalize)
local Rx = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.Rx)
local ToPropertyObservable = require(ReplicatedStorage.Knit.Util.Additions.Utility.ToPropertyObservable)

local JsonTranslator = {}
JsonTranslator.ClassName = "JsonTranslator"
JsonTranslator.__index = JsonTranslator

--[=[
	Constructs a new JsonTranslator from the given args.

	```lua
	local translator = JsonTranslator.new("en", {
		actions = {
			respawn = "Respawn {playerName}";
		};
	})

	print(translator:FormatByKey("actions.respawn"), { playerName = "Quenty"}) --> Respawn Quenty
	```

	```lua
	local translator = JsonTranslator.new(script)
	-- assume there is an `en.json` underneath the script with valid JSON.
	```

	@param ... any
	@return JsonTranslator
]=]
function JsonTranslator.new(...)
	local self = setmetatable({
		-- Cache LocalizationTable, because it can take 10-20ms to load.
		EnglishTranslator = nil;
		Fallbacks = {};
		LocalizationTable = JsonToLocalizationTable.ToLocalizationTable(...);
		PromiseTranslator = nil;
	}, JsonTranslator)

	self.EnglishTranslator = self.LocalizationTable:GetTranslator("en")

	if RunService:IsRunning() then
		self.LocalizationTable.Parent = LocalizationService
		self.PromiseTranslator = LocalizationServiceUtility.PromiseTranslator(Players.LocalPlayer)
	else
		self.PromiseTranslator = Promise.Resolve(self.EnglishTranslator)
	end

	if RunService:IsStudio() then
		PseudoLocalize.AddToLocalizationTable(self.LocalizationTable, nil, "en")
	end

	return self
end

--[=[
	Returns a promise that will resolve once the translator is loaded from the cloud.
	@return Promise
]=]
function JsonTranslator:PromiseLoaded()
	return self.PromiseTranslator
end

--[=[
	Makes the translator fall back to another translator if an entry cannot be found.
	Mostly just used for testing.
	@param translator JsonTranslator | Translator
]=]
function JsonTranslator:FallbackTo(Translator)
	assert(assert(Translator, "Bad translator").FormatByKey, "Bad translator")
	table.insert(self.Fallbacks, Translator)
end

--[=[
	Formats the resulting entry by args.
	@param key string
	@param args table?
	@return Promise<string>
]=]
function JsonTranslator:PromiseFormatByKey(Key: string, Arguments)
	assert(self ~= JsonTranslator, "Construct a new version of this class to use it")
	assert(type(Key) == "string", "Key must be a string")

	return self.PromiseTranslator:Then(function()
		return self:FormatByKey(Key, Arguments)
	end)
end

--[=[
	Observes the translated value
	@param key string
	@param argData table? -- May have observables (or convertible to observables) in it.
	@return Observable<string>
]=]
function JsonTranslator:ObserveFormatByKey(Key: string, ArgumentData)
	assert(self ~= JsonTranslator, "Construct a new version of this class to use it")
	assert(type(Key) == "string", "Key must be a string")

	local ArgumentObservable
	if ArgumentData then
		local Arguments = {}
		for ArgumentKey, ArgumentValue in next, ArgumentData do
			Arguments[ArgumentKey] = ToPropertyObservable(ArgumentValue) or Rx.Of(ArgumentValue)
		end

		ArgumentObservable = Rx.CombineLatest(Arguments)
	else
		ArgumentObservable = nil
	end

	return Observable.new(function(Subscription)
		local ObserveJanitor = Janitor.new()

		ObserveJanitor:AddPromise(self.PromiseTranslator:Then(function()
			if ArgumentObservable then
				ObserveJanitor:Add(ArgumentObservable:Subscribe(function(Arguments)
					Subscription:Fire(self:FormatByKey(Key, Arguments))
				end), "Destroy")
			else
				Subscription:Fire(self:FormatByKey(Key, nil))
			end
		end))

		return ObserveJanitor
	end)
end

--[=[
	Formats or errors if the cloud translations are not loaded.
	@param key string
	@param args table?
	@return string
]=]
function JsonTranslator:FormatByKey(Key: string, Arguments)
	assert(self ~= JsonTranslator, "Construct a new version of this class to use it")
	assert(type(Key) == "string", "Key must be a string")

	if not RunService:IsRunning() then
		return self:_FormatByKeyTestMode(Key, Arguments)
	end

	local ClientTranslator = self:_GetClientTranslatorOrError()
	local Result
	local Success, Error = pcall(function()
		Result = ClientTranslator:FormatByKey(Key, Arguments)
	end)

	if Success and not Error then
		return Result
	end

	if Error then
		warn(Error)
	else
		warn("Failed to localize '" .. Key .. "'")
	end

	-- Fallback to English
	if ClientTranslator.LocaleId ~= self.EnglishTranslator.LocaleId then
		-- Ignore results as we know this may error
		Success, Error = pcall(function()
			Result = self.EnglishTranslator:FormatByKey(Key, Arguments)
		end)

		if Success and not Error then
			return Result
		end
	end

	return Key
end

function JsonTranslator:_GetClientTranslatorOrError()
	assert(self.PromiseTranslator, "ClientTranslator is not initialized")

	if self.PromiseTranslator.Status == Promise.Status.Resolved then
		return assert(self.PromiseTranslator:Expect(), "Failed to get translator")
	else
		error("Translator is not yet acquired yet")
		return nil
	end
end

function JsonTranslator:_FormatByKeyTestMode(Key, Arguments)
	-- Can't read LocalizationService.ForcePlayModeRobloxLocaleId :(
	local Translator = self.LocalizationTable:GetTranslator("en")
	local Result
	local Success, Error = pcall(function()
		Result = Translator:FormatByKey(Key, Arguments)
	end)

	if Success and not Error then
		return Result
	end

	for _, Fallback in ipairs(self.Fallbacks) do
		local Value = Fallback:FormatByKey(Key, Arguments)
		if Value then
			return Value
		end
	end

	if Error then
		warn(Error)
	else
		warn("Failed to localize '" .. Key .. "'")
	end

	return Key
end

--[=[
	Cleans up the translator and deletes the localization table if it exists.
]=]
function JsonTranslator:Destroy()
	self.LocalizationTable:Destroy()
	self.LocalizationTable = nil
	self.EnglishTranslator = nil
	self.PromiseTranslator = nil

	setmetatable(self, nil)
end

function JsonTranslator:__tostring()
	return "JsonTranslator"
end

export type JsonTranslator = typeof(JsonTranslator.new(""))
table.freeze(JsonTranslator)
return JsonTranslator
