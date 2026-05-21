local Plugin = script:FindFirstAncestor("StudioActivity")

local BuildContext = require(script.Parent.BuildContext)
local Constants = require(Plugin.Source.Common.Constants)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
local interpolate = require(Plugin.Source.Common.interpolate)

export type ActivityConfig = createPresenceManager.ActivityConfig
type CustomProfileData = LocalStorageStore.CustomProfileData
type BuildContext = BuildContext.BuildContext

local STUDIO_LOGO_ASSET = "studio-logo"
local MAX_CUSTOM_BUTTONS = 2

local function resolveState(context: BuildContext, profile: CustomProfileData, templates: { [string]: string }): string?
	if context.studio.isPlayTesting and profile.activity.showTestingState then
		return "Playtesting"
	end

	local activeScript = context.studio.activeScript
	if activeScript and profile.activity.showCurrentScript then
		return `Editing {activeScript.name}`
	end

	local state = profile.activity.state
	return if state then interpolate(state, templates) else nil
end

local function buildCustomActivity(context: BuildContext, profile: CustomProfileData): ActivityConfig
	local place = context.place
	local onlineDetails = place.onlinePlaceDetails
	local offlineDetails = place.offlinePlaceDetails

	local details = profile.activity.details

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
		local remaining = MAX_CUSTOM_BUTTONS - #buttons
		local count = math.min(remaining, #profile.activity.customButtons)
		for i = 1, count do
			table.insert(buttons, profile.activity.customButtons[i])
		end
	end

	local activity: ActivityConfig = {
		name = "Roblox Studio",
		details = if details then interpolate(details, templates) else nil,
		state = resolveState(context, profile, templates),
		detailsUrl = Constants.PLUGIN_LINK_PROFILE_LINK,
		buttons = if #buttons > 0 then buttons else nil,
		assets = if profile.activity.showPlaceIcon and onlineDetails
			then {
				largeImage = onlineDetails.iconWebUrl,
				largeText = onlineDetails.placeName,
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
