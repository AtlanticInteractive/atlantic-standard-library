--[=[
	Utility methods for the binder object.
	@class BinderUtility
]=]

local CollectionService = game:GetService("CollectionService")
local Option = require(script.Parent.Parent.Parent.Option)

local BinderUtility = {}

--[=[
	Finds the first ancestor that is bound with the current child.
	Skips the child class, of course.

	@param binder Binder<T>
	@param child Instance
	@return T?
]=]
function BinderUtility.FindFirstAncestor(FindBinder, Child)
	assert(type(FindBinder) == "table", "Binder must be binder")
	assert(typeof(Child) == "Instance", "Child parameter must be instance")

	local Current = Child.Parent
	while Current do
		local Class = FindBinder:Get(Current)
		if Class then
			return Option.Some(Class)
		end

		Current = Current.Parent
	end

	return Option.None
end

--[=[
	Finds the first child bound with the given binder and returns
	the bound class.

	@param binder Binder<T>
	@param parent Instance
	@return T?
]=]
function BinderUtility.FindFirstChild(FindBinder, Parent)
	assert(type(FindBinder) == "table", "Binder must be binder")
	assert(typeof(Parent) == "Instance", "Parent parameter must be instance")

	for _, Child in ipairs(Parent:GetChildren()) do
		local Class = FindBinder:Get(Child)
		if Class then
			return Option.Some(Class)
		end
	end

	return Option.None
end

--[=[
	Gets all bound children of the given binder for the parent.

	@param binder Binder<T>
	@param parent Instance
	@return {T}
]=]
function BinderUtility.GetChildren(FindBinder, Parent)
	assert(type(FindBinder) == "table", "Binder must be binder")
	assert(typeof(Parent) == "Instance", "Parent parameter must be instance")

	local Objects = {}
	for _, Child in ipairs(Parent:GetChildren()) do
		local Class = FindBinder:Get(Child)
		if Class then
			table.insert(Objects, Class)
		end
	end

	return Objects
end

--[=[
	Maps a list of binders into a look up table where the keys are
	tags and the value is the binder.

	Duplicates are overwritten by the last entry.

	@param bindersList { Binder<any> }
	@return { [string]: Binder<any> }
]=]
function BinderUtility.MapBinderListToTable(BindersList)
	assert(type(BindersList) == "table", "bindersList must be a table of binders")

	local Tags = {}
	for _, MapBinder in ipairs(BindersList) do
		Tags[MapBinder.TagName] = MapBinder
	end

	return Tags
end

--[=[
	Given a mapping of tags to binders, retrieves the bound values
	from an instanceList by quering the list of :GetTags() instead
	of iterating over each binder.

	This lookup should be faster when there are potentially many
	interaction points for a given tag map, but the actual bound
	list should be low.

	@param tagsMap { [string]: Binder<T> }
	@param instanceList { Instance }
	@return { T }
]=]
function BinderUtility.GetMappedFromList(TagsMap, InstanceList: {Instance})
	local Objects = {}

	for _, Object in ipairs(InstanceList) do
		for _, Tag in ipairs(CollectionService:GetTags(Object)) do
			local Binder = TagsMap[Tag]
			if Binder then
				local Class = Binder:Get(Object)
				if Class then
					table.insert(Objects, Class)
				end
			end
		end
	end

	return Objects
end

--[=[
	Given a list of binders retrieves all children bound with the given value.

	@param bindersList { Binder<T> }
	@param parent Instance
	@return { T }
]=]
function BinderUtility.GetChildrenOfBinders(BindersList, Parent)
	assert(type(BindersList) == "table", "bindersList must be a table of binders")
	assert(typeof(Parent) == "Instance", "Parent parameter must be instance")

	local TagsMap = BinderUtility.MapBinderListToTable(BindersList)
	return BinderUtility.GetMappedFromList(TagsMap, Parent:GetChildren())
end

--[=[
	Gets all the linked (via objectValues of name `linkName`) bound objects

	@param binder Binder<T>
	@param linkName string -- Name of the object values required
	@param parent Instance
	@return {T}
]=]
function BinderUtility.GetLinkedChildren(Binder, LinkName, Parent)
	local Seen = {}
	local Objects = {}
	for _, Child in ipairs(Parent:GetChildren()) do
		if Child.Name == LinkName and Child:IsA("ObjectValue") and Child.Value then
			local Class = Binder:Get(Child.Value)
			if Class then
				if not Seen[Class] then
					Seen[Class] = true
					table.insert(Objects, Class)
				else
					warn(string.format("[BinderUtility.GetLinkedChildren] - Double linked children at %q", Child:GetFullName()))
				end
			end
		end
	end

	return Objects
end

--[=[
	Gets all bound descendants of the given binder for the parent.

	@param binder Binder<T>
	@param parent Instance
	@return {T}
]=]
function BinderUtility.GetDescendants(Binder, Parent)
	assert(type(Binder) == "table", "Binder must be binder")
	assert(typeof(Parent) == "Instance", "Parent parameter must be instance")

	local Objects = {}
	for _, Descendant in ipairs(Parent:GetDescendants()) do
		local Class = Binder:Get(Descendant)
		if Class then
			table.insert(Objects, Class)
		end
	end

	return Objects
end

table.freeze(BinderUtility)
return BinderUtility
