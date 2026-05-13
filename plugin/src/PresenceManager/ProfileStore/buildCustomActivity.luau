local Plugin = script:FindFirstAncestor("StudioActivity")

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
local interpolate = require(Plugin.Source.Common.interpolate)

export type ActivityConfig = createPresenceManager.ActivityConfig
type CustomProfileData = LocalStorageStore.CustomProfileData
type PlaceContext = PlaceDetailsStore.PlaceContext

local STUDIO_LOGO_ASSET = "studio-logo"

local function buildCustomActivity(context: PlaceContext, profile: CustomProfileData): ActivityConfig
	local onlineDetails = context.onlinePlaceDetails
	local offlineDetails = context.offlinePlaceDetails

	local details = profile.activity.details
	local state = profile.activity.state

	local templates = {
		placeName = if onlineDetails
			then onlineDetails.placeName
			elseif offlineDetails then offlineDetails.placeName
			else "",
		creator = if onlineDetails then onlineDetails.creatorName else "",
	}

	local activity: ActivityConfig = {
		name = "Roblox Studio",
		details = if details then interpolate(details, templates) else nil,
		detailsUrl = "https://github.com/grilme99/studio-activity",
		state = if state then interpolate(state, templates) else nil,
		assets = if profile.activity.showPlaceIcon and onlineDetails
			then {
				largeImage = onlineDetails.iconWebUrl,
				smallImage = STUDIO_LOGO_ASSET,
				smallText = "Studio Activity",
			}
			else {
				largeImage = STUDIO_LOGO_ASSET,
				largeText = "Studio Activity",
			},
	}

	return activity
end

return buildCustomActivity
