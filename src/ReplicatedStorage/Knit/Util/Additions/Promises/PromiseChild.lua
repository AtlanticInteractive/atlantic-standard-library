local Promise = require(script.Parent.Parent.Parent.Promise)
local TimeFunctions = require(script.Parent.Parent.Utility.TimeFunctions)

local function PromiseChild(Parent: Instance, ChildName: string, Timeout: number?)
	return Promise.new(function(Resolve, Reject, OnCancel)
		local Child = Parent:FindFirstChild(ChildName)
		if Child then
			Resolve(Child)
		else
			local Offset = Timeout or 5
			local StartTime = TimeFunctions.TimeFunction()
			local Cancelled = false
			local Connection

			if OnCancel(function()
				Cancelled = true
				if Connection then
					Connection = Connection:Disconnect()
				end

				return Reject("PromiseChild(" .. Parent:GetFullName() .. ", \"" .. tostring(ChildName) .. "\") was cancelled.")
			end) then
				return
			end

			Connection = Parent:GetPropertyChangedSignal("Parent"):Connect(function()
				if not Parent.Parent then
					if Connection then
						Connection = Connection:Disconnect()
					end

					Cancelled = true
					return Reject("PromiseChild(" .. Parent:GetFullName() .. ", \"" .. tostring(ChildName) .. "\") was cancelled.")
				end
			end)

			repeat
				task.wait(0.03)
				Child = Parent:FindFirstChild(ChildName)
			until Child or StartTime + Offset < TimeFunctions.TimeFunction() or Cancelled

			if Connection then
				Connection:Disconnect()
			end

			if not Timeout then
				Reject("Infinite yield possible for PromiseChild(" .. Parent:GetFullName() .. ", \"" .. tostring(ChildName) .. "\")")
			elseif Child then
				Resolve(Child)
			end
		end
	end)
end

return PromiseChild
