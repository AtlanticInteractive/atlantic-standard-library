local function GetFirstChild(Parent: Instance, ClassName: string, Name: string)
	for _, Child in ipairs(Parent:GetChildren()) do
		if Child:IsA(ClassName) and Child.Name == Name then
			return Child, false
		end
	end

	local Object = Instance.new(ClassName)
	Object.Name = Name
	Object.Parent = Parent
	return Object, true
end

return GetFirstChild
