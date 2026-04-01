local AssetService = game:GetService("AssetService")

local isShadowAvailable = pcall(function()
	Instance.new("UIShadow"):Destroy()
end)

local isDataModelContentApiAvailable = pcall(function()
	local editableImage = AssetService:CreateEditableImage({
		Size = Vector2.one,
	})

	AssetService:CreateDataModelContentAsync(Content.fromObject(editableImage))
	editableImage:Destroy()
end)

local Flags = {
	isShadowAvailable = isShadowAvailable,
	isDataModelContentApiAvailable = isDataModelContentApiAvailable,
}

return table.freeze(Flags)
