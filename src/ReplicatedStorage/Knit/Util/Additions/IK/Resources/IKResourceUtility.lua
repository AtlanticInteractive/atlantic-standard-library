--[=[
	@class IKResourceUtility
]=]

local IKResourceUtility = {}

export type ResourceData = {
	Children: {ResourceData}?,
	Name: string,
	RobloxName: string,
}

function IKResourceUtility.CreateResource(Data: ResourceData)
	assert(type(Data) == "table", "Bad data")
	assert(Data.Name, "Bad data.name")
	assert(Data.RobloxName, "Bad data.robloxName")

	return Data
end

table.freeze(IKResourceUtility)
return IKResourceUtility
