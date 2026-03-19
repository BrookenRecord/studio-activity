local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(Plugin.Source.Plugin.createPluginSettingsStore)

export type Credentials = {
	authToken: string?,
	clientKey: string?,
}

local defaultValue: Credentials = {
	authToken = nil,
	clientKey = nil,
}

local validate = t.interface({
	authToken = t.optional(t.string),
	clientKey = t.optional(t.string),
})

return {
	get = Charm.computed(function()
		return createPluginSettingsStore("PresenceApiCredentials", defaultValue, validate)
	end),
}
