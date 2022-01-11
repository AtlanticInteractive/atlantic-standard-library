--[=[
	Utility function to get rotation in the XZ plane.
	@class getRotationInXZPlane
]=]

--[=[
	Computes the rotation in the XZ plane relative to the origin.

	:::tip
	This function can be used to "flatten" a rotation so we just get the XZ rotation, which
	is the rotation you would see if we are looking directly top-down on the object.
	:::

	@param cframe CFrame
	@return CFrame -- The CFrame in the XZ plane
	@within getRotationInXZPlane
]=]
local function GetRotationInXZPlane(cframe)
	local _, _, _, _, _, zx, _, _, _, _, _, zz = cframe:GetComponents()

	local back = Vector3.new(zx, 0, zz).Unit
	if back ~= back then
		return cframe -- we're looking straight down
	end

	local right = Vector3.new(0, 1, 0):Cross(back)

	return CFrame.new(cframe.X, cframe.Y, cframe.Z, right.X, 0, back.X, right.Y, 1, back.Y, right.Z, 0, back.Z)
end

return GetRotationInXZPlane
