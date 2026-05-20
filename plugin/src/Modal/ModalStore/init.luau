local Plugin = script:FindFirstAncestor("StudioActivity")

local createModalStore = require(script.createModalStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)
export type ModalId = createModalStore.ModalId
export type ModalStackEntry = createModalStore.ModalStackEntry

return {
	get = createSingleton(createModalStore),
}
