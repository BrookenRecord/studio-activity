local Plugin = script:FindFirstAncestor("StudioActivity")

local createPluginStore = require(script.createPluginStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)

return {
	get = createSingleton(createPluginStore),
}
