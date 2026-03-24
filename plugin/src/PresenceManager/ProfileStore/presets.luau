local Plugin = script:FindFirstAncestor("StudioActivity")

local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
type ActivityConfig = createPresenceManager.ActivityConfig

local PlaceContext = require(Plugin.Source.PresenceManager.PlaceContext)
type PlaceContext = PlaceContext.PlaceContext

export type PresetProfile = {
	name: string,
	buildActivityAsync: (context: PlaceContext) -> ActivityConfig,
}

local presets: { [string]: PresetProfile } = {
	default = {
		name = "Default",
		buildActivityAsync = function(context: PlaceContext): ActivityConfig
			local details: string? = nil
			local detailsUrl: string? = nil

			if context.placeName then
				details = context.placeName
			end

			if context.placeId then
				detailsUrl = `https://www.roblox.com/games/{context.placeId}`
			end

			return {
				name = "Roblox Studio",
				details = details,
				detailsUrl = detailsUrl,
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
