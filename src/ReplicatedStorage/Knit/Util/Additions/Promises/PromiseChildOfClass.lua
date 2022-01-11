local Promise = require(script.Parent.Parent.Parent.Promise)
local TimeFunctions = require(script.Parent.Parent.Utility.TimeFunctions)

local function PromiseChildOfClass(Parent: Instance, ClassName: string, Timeout: number?)
	return Promise.new(function(Resolve, Reject, OnCancel)
		local Child = Parent:FindFirstChildOfClass(ClassName)
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

				return Reject("PromiseChildOfClass(" .. Parent:GetFullName() .. ", \"" .. tostring(ClassName) .. "\") was cancelled.")
			end) then
				return
			end

			Connection = Parent:GetPropertyChangedSignal("Parent"):Connect(function()
				if not Parent.Parent then
					if Connection then
						Connection = Connection:Disconnect()
					end

					Cancelled = true
					return Reject("PromiseChildOfClass(" .. Parent:GetFullName() .. ", \"" .. tostring(ClassName) .. "\") was cancelled.")
				end
			end)

			repeat
				task.wait(0.03)
				Child = Parent:FindFirstChildOfClass(ClassName)
			until Child or StartTime + Offset < TimeFunctions.TimeFunction() or Cancelled

			if Connection then
				Connection:Disconnect()
			end

			if not Timeout then
				Reject("Infinite yield possible for PromiseChildOfClass(" .. Parent:GetFullName() .. ", \"" .. tostring(ClassName) .. "\")")
			elseif Child then
				Resolve(Child)
			end
		end
	end)
end

return PromiseChildOfClass
