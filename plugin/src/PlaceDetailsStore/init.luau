local Plugin = script:FindFirstAncestor("StudioActivity")

local createPlaceDetailsStore = require(script.createPlaceDetailsStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)

export type PlaceType = createPlaceDetailsStore.PlaceType
export type Status = createPlaceDetailsStore.Status
export type OnlinePlaceDetails = createPlaceDetailsStore.OnlinePlaceDetails
export type OfflinePlaceDetails = createPlaceDetailsStore.OfflinePlaceDetails
export type PlaceContext = createPlaceDetailsStore.PlaceContext
export type PlaceEntry = createPlaceDetailsStore.PlaceEntry
export type PlaceDetailsStore = createPlaceDetailsStore.PlaceDetailsStore

return table.freeze({
	get = createSingleton(createPlaceDetailsStore),
})
