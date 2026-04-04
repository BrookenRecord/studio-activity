local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createPlaceContextStore = require(script.createPlaceContextStore)

export type PlaceType = createPlaceContextStore.PlaceType
export type Status = createPlaceContextStore.Status
export type OnlinePlaceDetails = createPlaceContextStore.OnlinePlaceDetails
export type OfflinePlaceDetails = createPlaceContextStore.OfflinePlaceDetails
export type PlaceContext = createPlaceContextStore.PlaceContext

return table.freeze({
	get = Charm.computed(function()
		return createPlaceContextStore()
	end),
})
