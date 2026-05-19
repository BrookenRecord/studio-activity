local Plugin = script:FindFirstAncestor("StudioActivity")

local Constants = require(Plugin.Source.Common.Constants)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
local interpolate = require(Plugin.Source.Common.interpolate)

export type ActivityConfig = createPresenceManager.ActivityConfig
type CustomProfileData = LocalStorageStore.CustomProfileData
type PlaceContext = PlaceDetailsStore.PlaceContext

local STUDIO_LOGO_ASSET = "studio-logo"
local MAX_CUSTOM_BUTTONS = 2

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

	local buttons: { createPresenceManager.ActivityConfigButton } = {}
	if onlineDetails and profile.activity.showJoinButton then
		table.insert(buttons, {
			label = "Play on Roblox",
			url = onlineDetails.placeLink,
		})
	end

	if profile.activity.showPluginButton then
		table.insert(buttons, {
			label = "Get Studio Activity",
			url = Constants.PLUGIN_LINK_PROFILE_BUTTON,
		})
	end

	if profile.activity.customButtons then
		local remainingButtons = MAX_CUSTOM_BUTTONS - #buttons
		for i = 1, remainingButtons do
			local customButton = profile.activity.customButtons[i]
			table.insert(buttons, customButton)
		end
	end

	local activity: ActivityConfig = {
		name = "Roblox Studio",
		details = if details then interpolate(details, templates) else nil,
		state = if state then interpolate(state, templates) else nil,
		detailsUrl = Constants.PLUGIN_LINK_PROFILE_LINK,
		buttons = if #buttons > 0 then buttons else nil,
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
