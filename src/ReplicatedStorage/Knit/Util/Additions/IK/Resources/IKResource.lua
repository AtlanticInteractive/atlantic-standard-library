--[=[
	@class IKResource
]=]

local BaseObject = require(script.Parent.Parent.Parent.Classes.BaseObject)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)

local IKResource = setmetatable({}, BaseObject)
IKResource.ClassName = "IKResource"
IKResource.__index = IKResource

function IKResource.new(Data)
	local self = setmetatable(BaseObject.new(), IKResource)

	self.Data = assert(Data, "Bad data")
	assert(Data.Name, "Bad data.name")
	assert(Data.RobloxName, "Bad data.robloxName")

	self.Instance = nil
	self.ChildResourceMap = {} -- [robloxName] = { data = data; ikResource = ikResource }
	self.DescendantLookupMap = {[Data.Name] = self}

	self.Ready = self.Janitor:Add(Instance.new("BoolValue"), "Destroy")
	self.ReadyChanged = self.Ready.Changed

	if self.Data.Children then
		for _, ChildData in ipairs(self.Data.Children) do
			self:_AddResource(IKResource.new(ChildData))
		end
	end

	return self
end

function IKResource:GetData()
	return self.Data
end

function IKResource:IsReady()
	return self.Ready.Value
end

function IKResource:Get(DescendantName)
	local Resource = self.DescendantLookupMap[DescendantName]
	if not Resource then
		error(string.format("[IKResource.Get] - Resource %q does not exist", tostring(DescendantName)))
	end

	local Result = Resource:GetInstance()
	if not Result then
		error("[IKResource.Get] - Not ready!")
	end

	return Result
end

function IKResource:GetInstance()
	if self.Data.IsLink then
		if self.Instance then
			return self.Instance.Value
		else
			return nil
		end
	end

	return self.Instance
end

function IKResource:SetInstance(Object)
	if self.Instance == Object then
		return
	end

	self.Janitor:Remove("InstanceJanitor")
	self.Instance = Object

	local InstanceJanitor = Janitor.new()

	if next(self.ChildResourceMap) then
		if Object then
			self:_StartListening(InstanceJanitor, Object)
		else
			self:_ClearChildren()
		end
	end

	if Object and self.Data.IsLink then
		assert(Object:IsA("ObjectValue"))
		self.Janitor:Add(Object.Changed:Connect(function()
			self:_UpdateReady()
		end), "Disconnect")
	end

	self.Janitor:Add(InstanceJanitor, "Destroy", "InstanceJanitor")
	self:_UpdateReady()
end

function IKResource:GetLookupTable()
	return self.DescendantLookupMap
end

function IKResource:_StartListening(InstanceJanitor, Object)
	for _, Child in ipairs(Object:GetChildren()) do
		self:_HandleChildAdded(Child)
	end

	InstanceJanitor:Add(Object.ChildAdded:Connect(function(Child)
		self:_HandleChildAdded(Child)
	end), "Disconnect")

	InstanceJanitor:Add(Object.ChildRemoved:Connect(function(Child)
		self:_HandleChildRemoved(Child)
	end), "Disconnect")
end

function IKResource:_AddResource(IkResource)
	local Data = IkResource.Data
	assert(Data.Name, "Bad data.name")
	assert(Data.RobloxName, "Bad data.robloxName")

	assert(type(Data.RobloxName) == "string", "Bad data.robloxName")
	assert(not self.ChildResourceMap[Data.RobloxName], "Data already exists")
	assert(not self.DescendantLookupMap[Data.Name], "Data already exists")

	self.ChildResourceMap[Data.RobloxName] = IkResource

	self.Janitor:Add(IkResource, "Destroy")
	self.Janitor:Add(IkResource.ReadyChanged:Connect(function()
		self:_UpdateReady()
	end), "Disconnect")

	-- Add to _descendantLookupMap, including the actual ikResource
	for Name, Resource in next, IkResource:GetLookupTable() do
		assert(not self.DescendantLookupMap[Name], "Resource already exists with name")

		self.DescendantLookupMap[Name] = Resource
	end
end

function IKResource:_HandleChildAdded(Child)
	local Resource = self.ChildResourceMap[Child.Name]
	if not Resource then
		return
	end

	Resource:SetInstance(Child)
end

function IKResource:_HandleChildRemoved(Child)
	local Resource = self.ChildResourceMap[Child.Name]
	if not Resource then
		return
	end

	if Resource:GetInstance() == Child then
		Resource:SetInstance(nil)
	end
end

function IKResource:_ClearChildren()
	for _, Child in next, self.ChildResourceMap do
		Child:SetInstance(nil)
	end
end

function IKResource:_UpdateReady()
	self.Ready.Value = self:_CalculateIsReady()
end

function IKResource:_CalculateIsReady()
	if not self.Instance then
		return false
	end

	if self.Data.IsLink then
		if not self.Instance.Value then
			return false
		end
	end

	for _, Child in next, self.ChildResourceMap do
		if not Child:IsReady() then
			return false
		end
	end

	return true
end

function IKResource:__tostring()
	return "IKResource"
end

table.freeze(IKResource)
return IKResource
