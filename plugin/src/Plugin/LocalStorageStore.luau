local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(script.Parent.createPluginSettingsStore)

local DiscordApi = require(Plugin.Source.Api.Discord)
type ApiUser = DiscordApi.User

export type LocalStorageStore = {
	wasUserPromptedForTelemetry: boolean,
	userDetailsCache: { [string]: ApiUser }?,
	disabledAccountIds: { [string]: true }?,
}

local defaultValue: LocalStorageStore = {
	wasUserPromptedForTelemetry = false,
	userDetailsCache = {},
	disabledAccountIds = {},
}

local validate = t.interface({
	wasUserPromptedForTelemetry = t.boolean,
	userDetailsCache = t.optional(t.table),
	disabledAccountIds = t.optional(t.table),
})

return {
	get = Charm.computed(function()
		return createPluginSettingsStore("PresenceLocalStorage", defaultValue, validate)
	end),
}
