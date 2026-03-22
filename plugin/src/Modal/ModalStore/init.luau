local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createModalStore = require(script.createModalStore)

return {
	get = Charm.computed(createModalStore),
}
