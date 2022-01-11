--[=[
	Utility to build a localization table from json, intended to be used with Rojo. Can also handle Rojo json
	objects turned into tables!

	@class JsonToLocalizationTable
]=]

local HttpService = game:GetService("HttpService")

local JsonToLocalizationTable = {}

local function RecursiveAdd(LocalizationTable: LocalizationTable, LocaleId, BaseKey, Object)
	if BaseKey ~= "" then
		BaseKey ..= "."
	end

	for Index, Value in next, Object do
		local Key = BaseKey .. Index
		if type(Value) == "table" then
			RecursiveAdd(LocalizationTable, LocaleId, Key, Value)
		elseif type(Value) == "string" then
			local Source = ""
			local Context = ""

			if LocaleId == "en" then
				Source = Value
			end

			LocalizationTable:SetEntryValue(Key, Source, Context, LocaleId, Value)
		else
			error("Bad type for value in '" .. Key .. "'.")
		end
	end
end

--[=[
	Extracts the locale from the name
	@param name string -- The name to parse
	@return string -- The locale
]=]
function JsonToLocalizationTable.LocaleFromName(Name: string)
	if string.sub(Name, -5) == ".json" then
		return string.sub(Name, 1, #Name - 5)
	else
		return Name
	end
end

--[=[
	Loads a folder into a localization table
	@param folder Folder -- A Roblox folder with StringValues containing JSON, named with the localization in mind
]=]
function JsonToLocalizationTable.LoadFolder(Folder: Folder): LocalizationTable
	local LocalizationTable = Instance.new("LocalizationTable")
	for _, Descendant in ipairs(Folder:GetDescendants()) do
		if Descendant:IsA("StringValue") then
			local LocaleId = JsonToLocalizationTable.LocaleFromName(Descendant.Name)
			JsonToLocalizationTable.AddJsonToTable(LocalizationTable, LocaleId, Descendant.Value)
		elseif Descendant:IsA("ModuleScript") then
			local LocaleId = JsonToLocalizationTable.LocaleFromName(Descendant.Name)
			RecursiveAdd(LocalizationTable, LocaleId, "", require(Descendant))
		end
	end

	return LocalizationTable
end

--[=[
	Extracts the locale from the folder, or a locale and table.
	@param first Instance | string
	@param second table?
	@return LocalizationTable
]=]
function JsonToLocalizationTable.ToLocalizationTable(First, Second): LocalizationTable
	if typeof(First) == "Instance" then
		local Result = JsonToLocalizationTable.LoadFolder(First)
		Result.Name = string.format("JSONTable_%s", First.Name)
		return Result
	elseif type(First) == "string" and type(Second) == "table" then
		local Result = JsonToLocalizationTable.LoadTable(First, Second)
		Result.Name = "JSONTable"
		return Result
	else
		error("Bad args")
	end
end

--[=[
	Extracts the locale from the name
	@param localeId string -- the defaultlocaleId
	@param dataTable table -- Data table to load from
	@return LocalizationTable
]=]
function JsonToLocalizationTable.LoadTable(LocaleId: string, DataTable)
	local LocalizationTable = Instance.new("LocalizationTable")
	RecursiveAdd(LocalizationTable, LocaleId, "", DataTable)
	return LocalizationTable
end

--[=[
	Adds json to a localization table
	@param localizationTable LocalizationTable -- The localization table to add to
	@param localeId string -- The localeId to use
	@param json string -- The json to add with
]=]
function JsonToLocalizationTable.AddJsonToTable(LocalizationTable: LocalizationTable, LocaleId: string, JsonString: string)
	RecursiveAdd(LocalizationTable, LocaleId, "", HttpService:JSONDecode(JsonString))
end

table.freeze(JsonToLocalizationTable)
return JsonToLocalizationTable
