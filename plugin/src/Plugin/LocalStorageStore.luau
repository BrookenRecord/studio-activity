local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(script.Parent.createPluginSettingsStore)

local DiscordApi = require(Plugin.Source.Api.Discord)
type ApiUser = DiscordApi.User

type CustomProfileActivityAssets = {
	largeImage: string?,
	largeText: string?,
	smallImage: string?,
	smallText: string?,
}

type CustomProfileActivity = {
	name: string,
	details: string?,
	detailsUrl: string?,
	state: string?,
	stateUrl: string?,
	startedAt: number?,
	assets: CustomProfileActivityAssets?,
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

local validateActivityAssets = t.interface({
	largeImage = t.optional(t.string),
	largeText = t.optional(t.string),
	smallImage = t.optional(t.string),
	smallText = t.optional(t.string),
})

local validateActivity = t.interface({
	name = t.string,
	details = t.optional(t.string),
	detailsUrl = t.optional(t.string),
	state = t.optional(t.string),
	stateUrl = t.optional(t.string),
	startedAt = t.optional(t.number),
	assets = t.optional(validateActivityAssets),
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
