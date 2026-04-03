local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
type ActivityConfig = createPresenceManager.ActivityConfig

local PlaceContextStore = require(Plugin.Source.PlaceContextStore)
type PlaceContext = PlaceContextStore.PlaceContext

local Logger = require(Plugin.Source.Logger)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local RetryBackoff = require(Plugin.Source.Api.RetryBackoff)
local createPluginSettingsStore = require(Plugin.Source.Plugin.createPluginSettingsStore)
local presets = require(script.Parent.presets)

local signal = Charm.signal
local effect = Charm.effect
local computed = Charm.computed

local MAX_BUILD_RETRIES = 3

export type CustomProfileData = {
	name: string,
	activity: ActivityConfig,
}

export type Profile = {
	name: string,
	isPreset: boolean,
	buildActivityAsync: (context: PlaceContext) -> ActivityConfig,
}

export type ProfileStore = {
	getActiveProfileId: () -> string,
	getActiveProfile: () -> Profile?,
	getAllProfiles: () -> { [string]: Profile },
	getResolvedActivity: () -> ActivityConfig?,

	setActiveProfile: (id: string) -> (),
	addCustomProfile: (id: string, data: CustomProfileData) -> (),
	updateCustomProfile: (id: string, data: CustomProfileData) -> (),
	removeCustomProfile: (id: string) -> (),

	destroy: () -> (),
	_settingsStore: createPluginSettingsStore.PluginSettingsStore<ProfileStoreData>,
}

type ProfileStoreData = {
	activeProfileId: string,
	customProfiles: { [string]: CustomProfileData },
}

local validateActivity = t.interface({
	name = t.string,
	details = t.optional(t.string),
	detailsUrl = t.optional(t.string),
	state = t.optional(t.string),
	stateUrl = t.optional(t.string),
	startedAt = t.optional(t.number),
	assets = t.optional(t.interface({
		largeImage = t.optional(t.string),
		largeText = t.optional(t.string),
		smallImage = t.optional(t.string),
		smallText = t.optional(t.string),
	})),
})

local validateCustomProfile = t.interface({
	name = t.string,
	activity = validateActivity,
})

local validate = t.interface({
	activeProfileId = t.string,
	customProfiles = t.map(t.string, validateCustomProfile),
})

local defaultValue: ProfileStoreData = {
	activeProfileId = "default",
	customProfiles = {},
}

--- Wrap a CustomProfileData into a runtime Profile.
--- The build function ignores context and returns the stored static activity.
local function wrapCustomProfile(data: CustomProfileData): Profile
	return {
		name = data.name,
		isPreset = false,
		buildActivityAsync = function(_context: PlaceContext): ActivityConfig
			return data.activity
		end,
	}
end

--- Wrap a preset into a runtime Profile.
local function wrapPreset(preset: presets.PresetProfile): Profile
	return {
		name = preset.name,
		isPreset = true,
		buildActivityAsync = preset.buildActivityAsync,
	}
end

--[[
	Retry a profile build with exponential backoff.
	The build function can yield. Returns nil on persistent failure.
]]
local function buildWithRetry(profile: Profile, context: PlaceContext): ActivityConfig?
	local backoffConfig = RetryBackoff.defaultConfig()
	local backoffState = RetryBackoff.createState()

	for attempt = 1, MAX_BUILD_RETRIES do
		local success, result = pcall(profile.buildActivityAsync, context)

		if success then
			return result
		end

		if attempt == MAX_BUILD_RETRIES then
			Logger:Warn(`ProfileStore: build failed after {MAX_BUILD_RETRIES} attempts: {result}`)
			NotificationStore.get().push("error", "Failed to build presence profile")
			return nil
		end

		local delay = RetryBackoff.nextAttempt(backoffConfig, backoffState)
		Logger:Warn(
			`ProfileStore: build error, retrying in {string.format("%.1f", delay)}s (attempt {attempt}/{MAX_BUILD_RETRIES}): {result}`
		)
		task.wait(delay)
	end

	-- Unreachable, but satisfies the type checker
	return nil
end

local function createProfileStore(): ProfileStore
	local settingsStore = createPluginSettingsStore("PresenceProfileStore", defaultValue, validate)

	local getActiveProfileId = computed(function(): string
		return settingsStore.getStorage().activeProfileId
	end)

	local getActiveProfile = computed(function(): Profile?
		local id = getActiveProfileId()
		local storage = settingsStore.getStorage()

		local preset = presets[id]
		if preset then
			return wrapPreset(preset)
		end

		local custom = storage.customProfiles[id]
		if custom then
			return wrapCustomProfile(custom)
		end

		return nil
	end)

	local getAllProfiles = computed(function(): { [string]: Profile }
		local all: { [string]: Profile } = {}

		for id, preset in presets do
			all[id] = wrapPreset(preset)
		end

		local storage = settingsStore.getStorage()
		for id, custom in storage.customProfiles do
			all[id] = wrapCustomProfile(custom)
		end

		return all
	end)

	-- Resolved activity from building the active profile against PlaceContext
	local getResolvedActivity, setResolvedActivity = signal(nil :: ActivityConfig?)
	local buildThread: thread?

	local disposeBuildEffect = effect(function()
		-- Cancel any in-flight build from a previous run
		if buildThread then
			pcall(task.cancel, buildThread)
		end

		local placeContextStore = PlaceContextStore.get()
		local context = placeContextStore.getContext()

		if context == nil then
			setResolvedActivity(nil)
			return
		end

		local profile = getActiveProfile()
		if not profile then
			setResolvedActivity(nil)
			return
		end

		buildThread = task.spawn(function()
			local activity = buildWithRetry(profile, context)
			setResolvedActivity(activity)
			buildThread = nil
		end)
	end)

	local function setActiveProfile(id: string)
		settingsStore.setStorage(function(prev: ProfileStoreData): ProfileStoreData
			return {
				activeProfileId = id,
				customProfiles = prev.customProfiles,
			}
		end)
	end

	local function addCustomProfile(id: string, data: CustomProfileData)
		settingsStore.setStorage(function(prev: ProfileStoreData): ProfileStoreData
			local customProfiles = table.clone(prev.customProfiles)
			customProfiles[id] = data
			return {
				activeProfileId = prev.activeProfileId,
				customProfiles = customProfiles,
			}
		end)
	end

	local function updateCustomProfile(id: string, data: CustomProfileData)
		settingsStore.setStorage(function(prev: ProfileStoreData): ProfileStoreData
			local customProfiles = table.clone(prev.customProfiles)
			customProfiles[id] = data
			return {
				activeProfileId = prev.activeProfileId,
				customProfiles = customProfiles,
			}
		end)
	end

	local function removeCustomProfile(id: string)
		settingsStore.setStorage(function(prev: ProfileStoreData): ProfileStoreData
			local customProfiles = table.clone(prev.customProfiles)
			customProfiles[id] = nil

			-- If the removed profile was active, fall back to default
			local activeId = prev.activeProfileId
			if activeId == id then
				activeId = "default"
			end

			return {
				activeProfileId = activeId,
				customProfiles = customProfiles,
			}
		end)
	end

	local function destroy()
		disposeBuildEffect()

		if buildThread then
			pcall(task.cancel, buildThread)
			buildThread = nil
		end

		settingsStore.dispose()
	end

	return {
		getActiveProfileId = getActiveProfileId,
		getActiveProfile = getActiveProfile,
		getAllProfiles = getAllProfiles,
		getResolvedActivity = getResolvedActivity,

		setActiveProfile = setActiveProfile,
		addCustomProfile = addCustomProfile,
		updateCustomProfile = updateCustomProfile,
		removeCustomProfile = removeCustomProfile,

		destroy = destroy,
		_settingsStore = settingsStore,
	}
end

return createProfileStore
