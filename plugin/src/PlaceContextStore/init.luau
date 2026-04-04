local createPlaceContextStore = require(script.createPlaceContextStore)

export type PlaceType = createPlaceContextStore.PlaceType
export type Status = createPlaceContextStore.Status
export type OnlinePlaceDetails = createPlaceContextStore.OnlinePlaceDetails
export type OfflinePlaceDetails = createPlaceContextStore.OfflinePlaceDetails
export type PlaceContext = createPlaceContextStore.PlaceContext

local instance = nil

local function get()
	if not instance then
		instance = createPlaceContextStore()
	end
	return instance
end

return table.freeze({ get = get })
