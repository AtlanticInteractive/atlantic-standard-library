local Children = require(script.Parent.Children)
local New = require(script.Parent.New)

local function CreateElement(Element, ElementProperties, ElementChildren)
	ElementProperties = ElementProperties or {}
	if ElementChildren then
		ElementProperties[Children] = ElementChildren
	end

	if type(Element) == "string" then
		return New(Element)(ElementProperties)
	else
		return Element(ElementProperties)
	end
end

return CreateElement
