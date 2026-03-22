local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createModalStore = require(script.createModalStore)

return {
	get = Charm.computed(createModalStore),
}
