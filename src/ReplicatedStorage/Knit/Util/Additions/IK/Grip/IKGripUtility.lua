--[=[
	Utility methods for grip attachments
	@class IKGripUtility
]=]

local IKGripUtility = {}

--[=[
	Parent to the attachment we want the humanoid to grip.

	```lua
	-- Get the binder
	local leftGripAttachmentBinder = serviceBag:GetService(require("IKBindersServer")).IKLeftGrip

	-- Setup sample grip
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.Name = "GripTarget"

	-- This will make the NPC try to grip this attachment
	local objectValue = IKGripUtility.create(leftGripAttachmentBinder, workspace.NPC.Humanoid)
	objectValue.Parent = attachment
	```

	@param binder Binder
	@param humanoid Humanoid
	@return ObjectValue
]=]
function IKGripUtility.Create(Binder, Humanoid: Humanoid)
	assert(Binder, "Bad binder")
	assert(typeof(Humanoid) == "Instance" and Humanoid:IsA("Humanoid"), "Bad humanoid")

	local ObjectValue = Instance.new("ObjectValue")
	ObjectValue.Name = Binder.TagName
	ObjectValue.Value = Humanoid

	Binder:Bind(ObjectValue)

	return ObjectValue
end

table.freeze(IKGripUtility)
return IKGripUtility
