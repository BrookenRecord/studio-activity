local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)

local BuildContext = require(script.Parent.BuildContext)
local Constants = require(Plugin.Source.Common.Constants)
local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)

local IconName = Foundation.Enums.IconName
type IconName = Foundation.IconName

type ActivityConfig = createPresenceManager.ActivityConfig
type BuildContext = BuildContext.BuildContext

local STUDIO_LOGO_ASSET = "studio-logo"

export type PresetProfile = {
	name: string,
	icon: IconName,
	buildActivityAsync: (context: BuildContext) -> ActivityConfig,
}

local function defaultState(context: BuildContext): string
	if context.studio.isPlayTesting then
		return "Testing"
	end

	local activeScript = context.studio.activeScript
	if activeScript then
		return `Editing {activeScript.name}`
	end

	return "Editing in Studio"
end

local presets: { [string]: PresetProfile } = {
	default = {
		name = "Default",
		icon = IconName.PhotoCameraFace :: IconName,
		buildActivityAsync = function(context: BuildContext): ActivityConfig
			local place = context.place
			local onlineDetails = if place.placeType == "online" then place.onlinePlaceDetails else nil
			local offlineDetails = if place.placeType == "offline" then place.offlinePlaceDetails else nil

			return {
				name = "Roblox Studio",
				details = if onlineDetails
					then onlineDetails.placeName
					elseif offlineDetails then offlineDetails.placeName
					else nil,
				state = defaultState(context),
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
		buildActivityAsync = function(_context: BuildContext): ActivityConfig
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
