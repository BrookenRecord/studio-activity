local isShadowAvailable = pcall(function()
	Instance.new("UIShadow"):Destroy()
end)

local Flags = {
	isShadowAvailable = isShadowAvailable,
}

return table.freeze(Flags)
