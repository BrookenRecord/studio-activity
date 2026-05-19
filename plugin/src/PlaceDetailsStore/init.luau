local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createPlaceDetailsStore = require(script.createPlaceDetailsStore)

export type PlaceType = createPlaceDetailsStore.PlaceType
export type Status = createPlaceDetailsStore.Status
export type OnlinePlaceDetails = createPlaceDetailsStore.OnlinePlaceDetails
export type OfflinePlaceDetails = createPlaceDetailsStore.OfflinePlaceDetails
export type PlaceContext = createPlaceDetailsStore.PlaceContext
export type PlaceEntry = createPlaceDetailsStore.PlaceEntry
export type PlaceDetailsStore = createPlaceDetailsStore.PlaceDetailsStore

return table.freeze({
	get = Charm.computed(function()
		return Charm.untracked(createPlaceDetailsStore)
	end),
})
