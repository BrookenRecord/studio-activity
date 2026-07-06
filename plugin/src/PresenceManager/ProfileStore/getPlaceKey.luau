type PlaceContext = {
	placeType: "offline" | "online",
	placeId: number,
	experienceId: number,

	offlinePlaceDetails: {
		placeName: string,
	}?,
}

local function getPlaceKey(placeContext: PlaceContext): string?
	if placeContext.placeType == "online" then
		if placeContext.experienceId and placeContext.experienceId > 0 then
			return `online:{placeContext.experienceId}`
		end

		if placeContext.placeId and placeContext.placeId > 0 then
			return `online-place:{placeContext.placeId}`
		end

		return nil
	end

	local offlineDetails = placeContext.offlinePlaceDetails
	local placeName = if offlineDetails then offlineDetails.placeName else game.Name
	if placeName == "" then
		return nil
	end

	return `local:{placeName}`
end

return getPlaceKey
