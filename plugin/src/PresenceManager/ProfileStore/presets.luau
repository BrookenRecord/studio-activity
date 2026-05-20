local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)

local Constants = require(Plugin.Source.Common.Constants)
local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)

local IconName = Foundation.Enums.IconName
type IconName = Foundation.IconName

type ActivityConfig = createPresenceManager.ActivityConfig
type PlaceContext = PlaceDetailsStore.PlaceContext

local STUDIO_LOGO_ASSET = "studio-logo"

export type PresetProfile = {
	name: string,
	icon: IconName,
	buildActivityAsync: (context: PlaceContext) -> ActivityConfig,
}

local presets: { [string]: PresetProfile } = {
	default = {
		name = "Default",
		icon = IconName.PhotoCameraFace :: IconName,
		buildActivityAsync = function(context: PlaceContext): ActivityConfig
			local onlineDetails = if context.placeType == "online" then context.onlinePlaceDetails else nil
			local offlineDetails = if context.placeType == "offline" then context.offlinePlaceDetails else nil

			return {
				name = "Roblox Studio",
				details = "Editing in Studio",
				state = if onlineDetails
					then onlineDetails.placeName
					elseif offlineDetails then offlineDetails.placeName
					else nil,
				detailsUrl = Constants.PLUGIN_LINK_PROFILE_LINK,
				buttons = if onlineDetails
					then {
						{ label = "Play on Roblox", url = onlineDetails.placeLink },
					}
					else nil,
				assets = if onlineDetails
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
		end,
	},

	confidential = {
		name = "Confidential",
		icon = IconName.Eyelashes :: IconName,
		buildActivityAsync = function(_context: PlaceContext): ActivityConfig
			return {
				name = "Roblox Studio",
				details = "Editing in Studio",
				detailsUrl = Constants.PLUGIN_LINK_PROFILE_LINK,
				assets = {
					largeImage = STUDIO_LOGO_ASSET,
					largeText = "Studio Activity",
				},
			}
		end,
	},
}

return table.freeze(presets)
