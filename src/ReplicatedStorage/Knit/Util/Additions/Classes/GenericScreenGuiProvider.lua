local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debug = require(script.Parent.Parent.Debugging.Debug)
local Typer = require(script.Parent.Parent.Debugging.Typer)

local GenericScreenGuiProvider = {}
GenericScreenGuiProvider.ClassName = "GenericScreenGuiProvider"
GenericScreenGuiProvider.__index = GenericScreenGuiProvider

function GenericScreenGuiProvider.new(LayoutOrders: {[string]: number})
	return setmetatable({
		LayoutOrders = LayoutOrders;
		MockParent = nil;
	}, GenericScreenGuiProvider)
end

function GenericScreenGuiProvider:__newindex(Index)
	Debug.Error("Bad index %s", Index)
end

function GenericScreenGuiProvider:Get(OrderName: string)
	if not RunService:IsRunning() then
		return self:_MockScreenGui(OrderName)
	end

	local LocalPlayer = Players.LocalPlayer
	if not LocalPlayer then
		error("[GenericScreenGuiProvider] - No localPlayer")
	end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = OrderName
	ScreenGui.ResetOnSpawn = false
	ScreenGui.AutoLocalize = false
	ScreenGui.DisplayOrder = self:GetDisplayOrder(OrderName)
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = assert(LocalPlayer:FindFirstChildOfClass("PlayerGui"), "No PlayerGui!")

	return ScreenGui
end

function GenericScreenGuiProvider:GetDisplayOrder(OrderName: string): number
	return Debug.Assert(self.LayoutOrders[OrderName], "No DisplayOrder with OrderName %q", OrderName)
end

function GenericScreenGuiProvider:SetupMockParent(Target)
	assert(not RunService:IsRunning())
	assert(Target)

	rawset(self, "MockParent", Target)

	return function()
		if rawget(self, "MockParent") == Target then
			rawset(self, "MockParent", nil)
		end
	end
end

function GenericScreenGuiProvider:_MockScreenGui(OrderName: string)
	assert(type(OrderName) == "string")
	assert(rawget(self, "MockParent"), "No MockParent set")

	local DisplayOrder = self:GetDisplayOrder(OrderName)

	local MockFrame = Instance.new("Frame")
	MockFrame.Size = UDim2.fromScale(1, 1)
	MockFrame.BackgroundTransparency = 1
	MockFrame.ZIndex = DisplayOrder
	MockFrame.Parent = rawget(self, "MockParent")

	return MockFrame
end

function GenericScreenGuiProvider:__tostring()
	return "GenericScreenGuiProvider"
end

export type GenericScreenGuiProvider = typeof(GenericScreenGuiProvider.new({A = 1}))

GenericScreenGuiProvider.new = Typer.AssignSignature(Typer.DictionaryOfIntegers, GenericScreenGuiProvider.new)
GenericScreenGuiProvider.GetDisplayOrder = Typer.AssignSignature(2, Typer.String, GenericScreenGuiProvider.GetDisplayOrder)

table.freeze(GenericScreenGuiProvider)
return GenericScreenGuiProvider
