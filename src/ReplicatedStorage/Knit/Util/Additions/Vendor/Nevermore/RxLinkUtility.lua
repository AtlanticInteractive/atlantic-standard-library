--[=[
	@class RxLinkUtility
]=]

local Brio = require(script.Parent.Brio)
local Janitor = require(script.Parent.Parent.Parent.Parent.Janitor)
local Observable = require(script.Parent.Observable)
local Rx = require(script.Parent.Rx)
local RxBrioUtility = require(script.Parent.RxBrioUtility)
local RxInstanceUtility = require(script.Parent.RxInstanceUtility)

local RxLinkUtility = {}

-- Emits valid links in format Brio.new(link, linkValue)
function RxLinkUtility.ObserveValidLinksBrio(LinkName, Parent)
	assert(type(LinkName) == "string", "linkName should be 'string'")
	assert(typeof(Parent) == "Instance", "parent should be 'Instance'")

	return RxInstanceUtility.ObserveChildrenBrio(Parent):Pipe({
		Rx.FlatMap(function(MapBrio)
			local Object = MapBrio:GetValue()
			if not Object:IsA("ObjectValue") then
				return Rx.EMPTY
			end

			return RxBrioUtility.CompleteOnDeath(MapBrio, RxLinkUtility.ObserveValidityBrio(LinkName, Object))
		end);
	})
end

-- Fires off everytime the link is reconfigured into a valid link
-- Fires with link, linkValue
function RxLinkUtility.ObserveValidityBrio(LinkName: string, Link: ObjectValue)
	assert(typeof(Link) == "Instance" and Link:IsA("ObjectValue"), "Bad link")
	assert(type(LinkName) == "string", "Bad linkName")

	return Observable.new(function(Subscription)
		local ObserveJanitor = Janitor.new()

		local function UpdateValidity()
			if not (Link.Name == LinkName and Link.Value) then
				return ObserveJanitor:Remove("LastValid")
			end

			Subscription:Fire(ObserveJanitor:Add(Brio.new(Link, Link.Value), "Destroy", "LastValid"))
		end

		ObserveJanitor:Add(Link:GetPropertyChangedSignal("Value"):Connect(UpdateValidity), "Disconnect")
		ObserveJanitor:Add(Link:GetPropertyChangedSignal("Name"):Connect(UpdateValidity), "Disconnect")
		UpdateValidity()

		return ObserveJanitor
	end)
end

table.freeze(RxLinkUtility)
return RxLinkUtility
