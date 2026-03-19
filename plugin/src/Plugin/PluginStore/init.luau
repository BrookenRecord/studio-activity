local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createPluginStore = require(script.createPluginStore)

return {
	get = Charm.computed(createPluginStore),
}
