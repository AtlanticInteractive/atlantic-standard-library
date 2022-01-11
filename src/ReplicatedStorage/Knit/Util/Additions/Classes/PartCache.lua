local Workspace = game:GetService("Workspace")
local Debug = require(script.Parent.Parent.Debugging.Debug)
local TableUtil = require(script.Parent.Parent.Parent.TableUtil)
local Typer = require(script.Parent.Parent.Debugging.Typer)

local PartCache = {}
PartCache.ClassName = "PartCache"
PartCache.__index = PartCache

local FAR_CFRAME = CFrame.new(0, 10E8, 0)
local STUPID_WARNING = "No parts available in the cache! Creating [%d] new part instance(s) - this amount can be edited by changing the ExpansionSize property of the PartCache instance. (This cache now contains a grand total of %d parts.)"

local function AssertWarn(Condition, Message, ...)
	if not Condition then
		Debug.Warn(Message or "Assertion failed!", ...)
	end

	return Condition
end

local function MakeFromTemplate(Template: BasePart, CurrentCacheParent: Instance)
	local BasePart = Template:Clone()
	BasePart.Anchored = true
	BasePart.CFrame = FAR_CFRAME
	BasePart.Parent = CurrentCacheParent
	return BasePart
end

function PartCache.new(Template: BasePart, PossiblePrecreatedParts: number?, PossibleCacheParent: Instance?)
	local PrecreatedParts = PossiblePrecreatedParts or 5
	local CacheParent = PossibleCacheParent or Workspace

	local OldArchivable = AssertWarn(Template.Archivable, "The template's Archivable property has been set to false, which prevents it from being cloned. It will temporarily be set to true.")
	Template.Archivable = true
	local NewTemplate = Template:Clone()
	Template.Archivable = OldArchivable

	Template = NewTemplate

	local self = setmetatable({
		Open = table.create(PrecreatedParts);
		InUse = table.create(PrecreatedParts);
		CurrentCacheParent = CacheParent;
		Template = Template;
		ExpansionSize = 10;
	}, PartCache)

	for Index = 1, PrecreatedParts do
		self.Open[Index] = MakeFromTemplate(Template, CacheParent)
	end

	self.Template:Remove()
	return self
end

function PartCache:GetPart(): BasePart
	if #self.Open == 0 then
		Debug.Warn(STUPID_WARNING, self.ExpansionSize, #self.Open + #self.InUse + self.ExpansionSize)

		for _ = 1, self.ExpansionSize do
			table.insert(self.Open, MakeFromTemplate(self.Template, self.CurrentCacheParent))
		end
	end

	local BasePart = table.remove(self.Open)
	table.insert(self.InUse, BasePart)
	return BasePart
end

function PartCache:ReturnPart(BasePart: BasePart)
	if TableUtil.SwapRemoveFirstValue(self.InUse, BasePart) then
		table.insert(self.Open, BasePart)
		BasePart.Anchored = true
		BasePart.CFrame = FAR_CFRAME
	else
		Debug.Error("Attempted to return %q to the cache, but it's not a member.", BasePart)
	end
end

function PartCache:SetCacheParent(CacheParent: Instance)
	self.CurrentCacheParent = CacheParent
	for _, BasePart in ipairs(self.Open) do
		BasePart.Parent = CacheParent
	end

	for _, BasePart in ipairs(self.InUse) do
		BasePart.Parent = CacheParent
	end
end

function PartCache:Expand(Amount: number?)
	for _ = 1, Amount or self.ExpansionSize do
		table.insert(self.Open, MakeFromTemplate(self.Template, self.CurrentCacheParent))
	end
end

function PartCache:Destroy()
	for _, BasePart in ipairs(self.Open) do
		BasePart:Destroy()
	end

	for _, BasePart in ipairs(self.InUse) do
		BasePart:Destroy()
	end

	self.Template:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end

function PartCache:__tostring()
	return "PartCache"
end

export type PartCache = typeof(PartCache.new(Instance.new("Part"), 5, Workspace))

local function GenerateIsValidCacheParent(IsOptional: boolean)
	if IsOptional then
		return function(Value: Instance, TypeOfString: string)
			if TypeOfString == "nil" then
				return true
			else
				return TypeOfString == "Instance" and (Value == Workspace or Value:IsDescendantOf(Workspace))
			end
		end
	else
		return function(Value: Instance, TypeOfString: string)
			return TypeOfString == "Instance" and (Value == Workspace or Value:IsDescendantOf(Workspace))
		end
	end
end

PartCache.new = Typer.AssignSignature(Typer.InstanceWhichIsABasePart, Typer.OptionalPositiveInteger, {CacheParent = GenerateIsValidCacheParent(true)}, PartCache.new) :: (Template: BasePart, PossiblePrecreatedParts: number?, PossibleCacheParent: Instance?) -> PartCache

PartCache.ReturnPart = Typer.AssignSignature(2, {CacheParent = GenerateIsValidCacheParent(false)}, PartCache.ReturnPart)
PartCache.Expand = Typer.AssignSignature(2, Typer.OptionalInteger, PartCache.Expand)
table.freeze(PartCache)
return PartCache
