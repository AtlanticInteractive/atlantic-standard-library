--[=[
	Tracks current cooldown on an object
	@class CooldownTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.BaseObject)
local CatchFactory = require(ReplicatedStorage.Knit.Util.Additions.Promises.CatchFactory)
local CooldownBinders = require(script.Parent.CooldownBinders)
local RxBinderUtility = require(ReplicatedStorage.Knit.Util.Additions.Vendor.Nevermore.RxBinderUtility)
local ValueObject = require(ReplicatedStorage.Knit.Util.Additions.Classes.ValueObject)

local CooldownTracker = setmetatable({}, BaseObject)
CooldownTracker.ClassName = "CooldownTracker"
CooldownTracker.__index = CooldownTracker

function CooldownTracker.new(Parent)
	local self = setmetatable(BaseObject.new(assert(Parent, "No parent")), CooldownTracker)
	self.CooldownBinders = CooldownBinders
	self.CurrentCooldown = self.Janitor:Add(ValueObject.new(), "Destroy")

	self.Janitor:Add(self.CurrentCooldown.Changed:Connect(function(New, _, ValueJanitor)
		if New then
			ValueJanitor:Add(New.Done:Connect(function()
				if self.CurrentCooldown.Value == New then
					self.CurrentCooldown.Value = nil
				end
			end), "Disconnect")
		end
	end), "Disconnect")

	-- Handle not running
	self.Janitor:AddPromise(self.CooldownBinders:PromiseBinder("Cooldown")):Then(function(CooldownBinder)
		self.Janitor:Add(RxBinderUtility.ObserveBoundChildClassBrio(CooldownBinder, self.Object):Subscribe(function(Brio)
			if Brio:IsDead() then
				return
			end

			local Cooldown = Brio:GetValue()
			local BrioJanitor = Brio:ToJanitor()
			self.CurrentCooldown.Value = Cooldown

			BrioJanitor:Add(function()
				if self.CurrentCooldown.Value == Cooldown then
					self.CurrentCooldown.Value = nil
				end
			end, true)
		end), "Destroy")
	end):Catch(CatchFactory("CooldownBinders.PromiseBinder"))

	return self
end

function CooldownTracker:__tostring()
	return "CooldownTracker"
end

table.freeze(CooldownTracker)
return CooldownTracker
