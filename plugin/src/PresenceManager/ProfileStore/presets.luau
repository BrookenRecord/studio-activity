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
			assert(context.placeType == "online")

			return {
				name = "Roblox Studio",
				details = "Editing in Studio",
				state = context.onlinePlaceDetails.placeName,
				stateUrl = context.onlinePlaceDetails.placeLink,
				assets = {
					largeImage = context.onlinePlaceDetails.iconWebUrl,
				},
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
