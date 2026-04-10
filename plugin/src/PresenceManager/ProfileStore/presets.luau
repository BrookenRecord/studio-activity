local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)

local IconName = Foundation.Enums.IconName
type IconName = Foundation.IconName

local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
type ActivityConfig = createPresenceManager.ActivityConfig

local PlaceContextStore = require(Plugin.Source.PlaceContextStore)
type PlaceContext = PlaceContextStore.PlaceContext

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
				stateUrl = if onlineDetails then onlineDetails.placeLink else nil,
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
				assets = {
					largeImage = STUDIO_LOGO_ASSET,
					largeText = "Studio Activity",
				},
			}
		end,
	},
}

return table.freeze(presets)
