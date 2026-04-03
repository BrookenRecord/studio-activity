local Plugin = script:FindFirstAncestor("StudioActivity")

local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
type ActivityConfig = createPresenceManager.ActivityConfig

local PlaceContextStore = require(Plugin.Source.PlaceContextStore)
type PlaceContext = PlaceContextStore.PlaceContext

export type PresetProfile = {
	name: string,
	buildActivityAsync: (context: PlaceContext) -> ActivityConfig,
}

local presets: { [string]: PresetProfile } = {
	default = {
		name = "Default",
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
					}
					else nil,
			}
		end,
	},

	confidential = {
		name = "Confidential",
		buildActivityAsync = function(_context: PlaceContext): ActivityConfig
			return {
				name = "Roblox Studio",
			}
		end,
	},
}

return table.freeze(presets)
