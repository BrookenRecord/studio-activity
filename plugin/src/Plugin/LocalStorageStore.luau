local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local Logger = require(Plugin.Source.Logger)
local createPluginSettingsStore = require(script.Parent.createPluginSettingsStore)

local DiscordApi = require(Plugin.Source.Api.Discord)
type ApiUser = DiscordApi.User

export type CustomProfileButton = {
	label: string,
	url: string,
}

--[[
	NOTE: All optional fields here are intentionally tri-state — `nil` means
	"use the runtime default" (which can differ per field), and `true`/`false`
	are explicit user choices. To clear a previously-set value back to the
	default, callers must merge in `Sift.None` rather than `nil`, otherwise
	the existing value will be kept by `Sift.Dictionary.mergeDeep`.
]]
type CustomProfileActivity = {
	details: string?,
	state: string?,
	buttons: { CustomProfileButton }?,
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

-- Lenient at the top level: `customProfiles` is validated per-entry in
-- `validate` below so that one corrupt profile doesn't blow away the entire
-- LocalStorage payload.
local validateInterface = t.interface({
	hasCompletedOnboarding = t.boolean,
	isPresenceActive = t.optional(t.boolean),
	selectedProfileId = t.optional(t.string),
	customProfiles = t.optional(t.table),
	userDetailsCache = t.optional(t.table),
	disabledAccountIds = t.optional(t.table),
})

--[[
	Validates the full LocalStorage payload. Drops malformed `customProfiles`
	entries in-place (logging a warning per drop) before applying the strict
	top-level interface check, so a single corrupt profile doesn't cause us
	to discard everything.
]]
local function validate(value: any): (boolean, string)
	if typeof(value) == "table" and typeof(value.customProfiles) == "table" then
		for id, profile in value.customProfiles do
			local isValid, message = validateCustomProfile(profile)
			if not isValid then
				Logger:Warn(`LocalStorageStore: dropping malformed custom profile "{id}": {message}`)
				value.customProfiles[id] = nil
			end
		end
	end

	local isValid, message = validateInterface(value)
	return isValid, message or ""
end

return {
	get = Charm.computed(function()
		return createPluginSettingsStore("PresenceLocalStorage", defaultValue, validate)
	end),
}
