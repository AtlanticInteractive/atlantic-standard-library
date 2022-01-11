--!strict

-- StreamableUtil
-- Stephen Leitnick
-- March 03, 2021

local Janitor = require(script.Parent.Janitor)
local _Streamable = require(script.Parent.Streamable)

type Streamables = {_Streamable.Streamable}
type CompoundHandler = (Streamables, any) -> nil

--[=[
	@class StreamableUtil
	A utility library for the Streamable class.

	```lua
	local StreamableUtil = require(packages.Streamable).StreamableUtil
	```
]=]
local StreamableUtil = {}

--[=[
	@param streamables {Streamable}
	@param handler ({[child: string]: Instance}, janitor: Janitor) -> nil
	@return Janitor

	Creates a compound streamable around all the given streamables. The compound
	streamable's observer handler will be fired once _all_ the given streamables
	are in existence, and will be cleaned up when _any_ of the streamables
	disappear.

	```lua
	local s1 = Streamable.new(workspace, "Part1")
	local s2 = Streamable.new(workspace, "Part2")

	local compoundJanitor = StreamableUtil.Compound({S1 = s1, S2 = s2}, function(streamables, janitor)
		local part1 = streamables.S1.Instance
		local part2 = streamables.S2.Instance
		janitor:Add(function()
			print("Cleanup")
		end, true)
	end)
	```
]=]
function StreamableUtil.Compound(streamables: Streamables, handler: CompoundHandler): Janitor.Janitor
	local compoundJanitor = Janitor.new()
	local observeAllJanitor = Janitor.new()
	local allAvailable = false
	local function Check()
		if allAvailable then
			return
		end

		for _, streamable in next, streamables do
			if not streamable.Instance then
				return
			end
		end

		allAvailable = true
		handler(streamables, observeAllJanitor)
	end

	local function Cleanup()
		if not allAvailable then
			return
		end

		allAvailable = false
		observeAllJanitor:Cleanup()
	end

	for _, streamable in next, streamables do
		compoundJanitor:Add(streamable:Observe(function(_, janitor: Janitor.Janitor)
			Check()
			janitor:Add(Cleanup, true)
		end), "Disconnect")
	end

	compoundJanitor:Add(Cleanup, true)
	return compoundJanitor
end

table.freeze(StreamableUtil)
return StreamableUtil
