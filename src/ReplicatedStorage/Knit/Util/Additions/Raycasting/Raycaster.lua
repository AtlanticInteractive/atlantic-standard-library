local Workspace = game:GetService("Workspace")
local Option = require(script.Parent.Parent.Parent.Option)

local Raycaster = {}
Raycaster.ClassName = "Raycaster"
Raycaster.__index = Raycaster

type FilterFunction = (RaycastResult: RaycastResult) -> boolean

function Raycaster.new(FilterFunction: FilterFunction?)
	local self = setmetatable({
		Parameters = RaycastParams.new();
		MaxCasts = 5;
		IgnoreList = {};
		Filter = FilterFunction;
	}, Raycaster)

	self.Parameters.FilterDescendantsInstances = self.IgnoreList
	self.Parameters.FilterType = Enum.RaycastFilterType.Blacklist
	self.Parameters.IgnoreWater = false

	return self
end

local function TryRaycast(self: Raycaster, Origin: Vector3, Direction: Vector3, IgnoreList: {Instance})
	local Parameters = self.Parameters
	Parameters.FilterDescendantsInstances = IgnoreList

	local RaycastResult = Workspace:Raycast(Origin, Direction, Parameters)
	if not RaycastResult then
		return true, false
	end

	local Filter = self.Filter
	if Filter and Filter(RaycastResult) then
		table.insert(IgnoreList, RaycastResult.Instance)
		return false
	end

	return true, RaycastResult
end

function Raycaster:Ignore(ArrayOrInstance: {Instance} | Instance)
	if type(ArrayOrInstance) == "table" then
		local IgnoreList = self.IgnoreList
		for _, Object in ipairs(ArrayOrInstance :: {Instance}) do
			table.insert(IgnoreList, Object)
		end

		self.Parameters.FilterDescendantsInstances = IgnoreList
	else
		table.insert(self.IgnoreList, ArrayOrInstance)
		self.Parameters.FilterDescendantsInstances = self.IgnoreList
	end
end

function Raycaster:Raycast(Origin: Vector3, Direction: Vector3): Option.Option<RaycastResult>
	local LocalIgnoreList = self.IgnoreList
	local Length = #LocalIgnoreList

	local IgnoreList = table.move(LocalIgnoreList, 1, Length, 1, table.create(Length))
	local Casts = self.MaxCasts

	while Casts > 0 do
		local Success, RaycastResult = TryRaycast(self, Origin, Direction, IgnoreList)
		if Success then
			return Option.Some(RaycastResult)
		else
			Casts -= 1
		end
	end

	warn(string.format("[Raycaster.Raycast] - Cast %d times, ran out of casts\n%s", self.MaxCasts, debug.traceback()))
	return Option.None
end

function Raycaster:RaycastNoOption(Origin: Vector3, Direction: Vector3): RaycastResult?
	local LocalIgnoreList = self.IgnoreList
	local Length = #LocalIgnoreList

	local IgnoreList = table.move(LocalIgnoreList, 1, Length, 1, table.create(Length))
	local Casts = self.MaxCasts

	while Casts > 0 do
		local Success, RaycastResult = TryRaycast(self, Origin, Direction, IgnoreList)
		if Success then
			return RaycastResult
		else
			Casts -= 1
		end
	end

	warn(string.format("[Raycaster.Raycast] - Cast %d times, ran out of casts\n%s", self.MaxCasts, debug.traceback()))
	return nil
end

function Raycaster:FindPartOnRay(Ray: Ray): Option.Option<RaycastResult>
	return self:Raycast(Ray.Origin, Ray.Direction)
end

function Raycaster:FindPartOnRayNoOption(Ray: Ray): RaycastResult?
	return self:RaycastNoOption(Ray.Origin, Ray.Direction)
end

function Raycaster:GetIgnoreList(): {Instance}
	return self.IgnoreList
end

function Raycaster:GetFilter(): FilterFunction?
	return self.Filter
end

function Raycaster:GetIgnoreWater(): boolean
	return self.Parameters.IgnoreWater
end

function Raycaster:GetMaxCasts(): number
	return self.MaxCasts
end

function Raycaster:SetFilter(FilterFunction: FilterFunction?)
	self.Filter = FilterFunction
	return self
end

function Raycaster:SetIgnoreWater(IgnoreWater: boolean)
	self.Parameters.IgnoreWater = IgnoreWater
	return self
end

function Raycaster:SetMaxCasts(MaxCasts: number)
	self.MaxCasts = MaxCasts
	return self
end

function Raycaster:__tostring()
	return "Raycaster"
end

export type Raycaster = typeof(Raycaster.new())
table.freeze(Raycaster)
return Raycaster
