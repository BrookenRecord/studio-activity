local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createModalStore = require(script.createModalStore)
export type ModalId = createModalStore.ModalId
export type ModalStackEntry = createModalStore.ModalStackEntry

return {
	get = Charm.computed(createModalStore),
}
