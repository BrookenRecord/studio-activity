local Plugin = script:FindFirstAncestor("StudioActivity")

local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local PluginContextStore = require(Plugin.Source.PluginContextStore)

export type BuildContext = {
	place: PlaceDetailsStore.PlaceContext,
	studio: PluginContextStore.StudioContext,
}

return {}
