local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(script.Parent.createPluginSettingsStore)

local DiscordApi = require(Plugin.Source.Api.Discord)
type ApiUser = DiscordApi.User

type CustomProfileActivity = {
	details: string?,
	state: string?,
	showPlaceIcon: boolean?,
	overridePlaceId: number?,
}

export type CustomProfileData = {
	name: string,
	activity: CustomProfileActivity,
}

export type CustomProfiles = { [string]: CustomProfileData }

export type LocalStorageStore = {
	hasCompletedOnboarding: boolean,
	isPresenceActive: boolean?,
	selectedProfileId: string?,
	customProfiles: CustomProfiles?,
	userDetailsCache: { [string]: ApiUser }?,
	disabledAccountIds: { [string]: true }?,
}

local defaultValue: LocalStorageStore = {
	hasCompletedOnboarding = false,
	isPresenceActive = true,
	selectedProfileId = nil,
	customProfiles = {},
	userDetailsCache = {},
	disabledAccountIds = {},
}

local validateActivity = t.interface({
	details = t.optional(t.string),
	state = t.optional(t.string),
	showPlaceIcon = t.optional(t.boolean),
	overridePlaceId = t.optional(t.number),
})

local validateCustomProfile = t.interface({
	name = t.string,
	activity = validateActivity,
})

local validate = t.interface({
	hasCompletedOnboarding = t.boolean,
	isPresenceActive = t.optional(t.boolean),
	selectedProfileId = t.optional(t.string),
	customProfiles = t.optional(t.map(t.string, validateCustomProfile)),
	userDetailsCache = t.optional(t.table),
	disabledAccountIds = t.optional(t.table),
})

return {
	get = Charm.computed(function()
		return createPluginSettingsStore("PresenceLocalStorage", defaultValue, validate)
	end),
}
