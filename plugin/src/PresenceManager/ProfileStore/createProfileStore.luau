local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)

local PresenceManager = require(Plugin.Source.PresenceManager)
local createPresenceManager = require(Plugin.Source.PresenceManager.createPresenceManager)
type ActivityConfig = createPresenceManager.ActivityConfig

local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)

local PluginContextStore = require(Plugin.Source.PluginContextStore)

local BuildContextModule = require(script.Parent.BuildContext)
type BuildContext = BuildContextModule.BuildContext

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local Logger = require(Plugin.Source.Logger)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local RetryBackoff = require(Plugin.Source.Api.RetryBackoff)
local buildCustomActivity = require(script.Parent.buildCustomActivity)
local getPlaceKey = require(script.Parent.getPlaceKey)
local presets = require(script.Parent.presets)

local IconName = Foundation.Enums.IconName

local signal = Charm.signal
local effect = Charm.effect
local computed = Charm.computed
local peek = Charm.peek

local MAX_BUILD_RETRIES = 3

type CustomProfileData = LocalStorageStore.CustomProfileData
type CustomProfiles = LocalStorageStore.CustomProfiles

export type Profile = {
	name: string,
	icon: Foundation.IconName,
	isPreset: boolean,
	sortOrder: number,
	overridePlaceId: number?,
	buildActivityAsync: (context: BuildContext) -> ActivityConfig,
}

export type ProfileStore = {
	getActiveProfileId: () -> string,
	getActiveProfile: () -> Profile?,
	getAllProfiles: () -> { [string]: Profile },
	getResolvedActivity: () -> ActivityConfig?,
	getCurrentPlaceKey: () -> string?,
	getPinnedProfileIdForCurrentPlace: () -> string?,
	getIsCurrentPlacePinned: () -> boolean,

	setActiveProfile: (id: string) -> (),
	pinCurrentPlaceToProfile: (profileId: string) -> (),
	unpinCurrentPlace: () -> (),
	toggleCurrentPlacePin: () -> (),
	setCustomProfile: (id: string, data: CustomProfileData) -> (),
	removeCustomProfile: (id: string) -> (),

	destroy: () -> (),
}

--- Wrap a CustomProfileData into a runtime Profile.
--- The build function ignores context and returns the stored static activity.
local function wrapCustomProfile(data: CustomProfileData): Profile
	return {
		name = data.name,
		icon = IconName.DiamondSimplified :: Foundation.IconName,
		isPreset = false,
		-- Custom profiles are sorted alphabetically in a separate bucket,
		-- so this value is unused; included only to satisfy the Profile type.
		sortOrder = 0,
		overridePlaceId = data.activity.overridePlaceId,
		buildActivityAsync = function(context: BuildContext): ActivityConfig
			return buildCustomActivity(context, data)
		end,
	}
end

--- Wrap a preset into a runtime Profile.
local function wrapPreset(preset: presets.PresetProfile): Profile
	return {
		name = preset.name,
		icon = preset.icon,
		isPreset = true,
		sortOrder = preset.sortOrder,
		overridePlaceId = nil,
		buildActivityAsync = preset.buildActivityAsync,
	}
end

--[[
	Retry a profile build with exponential backoff.
	The build function can yield. Returns nil on persistent failure.
]]
local function buildWithRetry(profile: Profile, context: BuildContext): ActivityConfig?
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
	local localStorage = LocalStorageStore.get()
	local placeDetailsStore = PlaceDetailsStore.get()
	local pluginContextStore = PluginContextStore.get()
	local presenceManager = PresenceManager.get()

	local getActiveProfileId = computed(function(): string
		return localStorage.getStorage().selectedProfileId or "default"
	end)

	local getCurrentPlaceKey = computed(function(): string?
		local placeContext = placeDetailsStore.getCurrentContext()
		if placeContext == nil then
			return nil
		end

		return getPlaceKey(placeContext)
	end)

	local getPinnedProfileIdForCurrentPlace = computed(function(): string?
		local currentPlaceKey = getCurrentPlaceKey()
		if currentPlaceKey == nil then
			return nil
		end

		local pinnedProfileIdsByPlaceKey: { [string]: string } = localStorage.getStorage().pinnedProfileIdsByPlaceKey
			or {}
		return pinnedProfileIdsByPlaceKey[currentPlaceKey]
	end)

	local getIsCurrentPlacePinned = computed(function(): boolean
		return getPinnedProfileIdForCurrentPlace() ~= nil
	end)

	local function setSelectedProfileId(id: string, shouldUpdateCurrentPlacePin: boolean)
		local currentPlaceKey = if shouldUpdateCurrentPlacePin then peek(getCurrentPlaceKey) else nil

		localStorage.setStorage(function(prev)
			local new = table.clone(prev)
			new.selectedProfileId = id

			if currentPlaceKey then
				local pinnedProfileIdsByPlaceKey: { [string]: string } = prev.pinnedProfileIdsByPlaceKey or {}
				if pinnedProfileIdsByPlaceKey[currentPlaceKey] ~= nil then
					local newPinnedProfileIdsByPlaceKey = table.clone(pinnedProfileIdsByPlaceKey)
					newPinnedProfileIdsByPlaceKey[currentPlaceKey] = id
					new.pinnedProfileIdsByPlaceKey = newPinnedProfileIdsByPlaceKey
				end
			end

			return new
		end)
	end

	local function setActiveProfile(id: string)
		setSelectedProfileId(id, true)
	end

	local function pinCurrentPlaceToProfile(profileId: string)
		local currentPlaceKey = peek(getCurrentPlaceKey)
		if currentPlaceKey == nil then
			return
		end

		localStorage.setStorage(function(prev)
			local new = table.clone(prev)
			local prevPinnedProfileIdsByPlaceKey: { [string]: string } = prev.pinnedProfileIdsByPlaceKey or {}
			local pinnedProfileIdsByPlaceKey = table.clone(prevPinnedProfileIdsByPlaceKey)
			pinnedProfileIdsByPlaceKey[currentPlaceKey] = profileId
			new.pinnedProfileIdsByPlaceKey = pinnedProfileIdsByPlaceKey
			new.selectedProfileId = profileId
			return new
		end)
	end

	local function unpinCurrentPlace()
		local currentPlaceKey = peek(getCurrentPlaceKey)
		if currentPlaceKey == nil then
			return
		end

		localStorage.setStorage(function(prev)
			local pinnedProfileIdsByPlaceKey: { [string]: string } = prev.pinnedProfileIdsByPlaceKey or {}
			if pinnedProfileIdsByPlaceKey[currentPlaceKey] == nil then
				return prev
			end

			local new = table.clone(prev)
			local newPinnedProfileIdsByPlaceKey = table.clone(pinnedProfileIdsByPlaceKey)
			newPinnedProfileIdsByPlaceKey[currentPlaceKey] = nil
			new.pinnedProfileIdsByPlaceKey = newPinnedProfileIdsByPlaceKey
			return new
		end)
	end

	local function toggleCurrentPlacePin()
		if peek(getIsCurrentPlacePinned) then
			unpinCurrentPlace()
		else
			pinCurrentPlaceToProfile(peek(getActiveProfileId))
		end
	end

	local getActiveProfile = computed(function(): Profile?
		local id = getActiveProfileId()
		local customProfiles = localStorage.getStorage().customProfiles or {}

		local preset = presets[id]
		if preset then
			return wrapPreset(preset)
		end

		local custom = customProfiles[id]
		if custom then
			return wrapCustomProfile(custom)
		end

		return wrapPreset(presets.default)
	end)

	-- Reset to default when the active profile no longer exists.
	-- This is an effect rather than inline in the computed above to
	-- avoid writing to a signal during a computed derivation.
	local disposeProfileFallbackEffect = effect(function()
		local id = getActiveProfileId()
		local customProfiles = localStorage.getStorage().customProfiles or {}

		if id ~= "default" and not presets[id] and not customProfiles[id] then
			setSelectedProfileId("default", false)
		end
	end)

	local disposeApplyPinnedProfileEffect = effect(function()
		local currentPlaceKey = getCurrentPlaceKey()
		if currentPlaceKey == nil then
			return
		end

		local storage = localStorage.getStorage()
		local pinnedProfileIdsByPlaceKey: { [string]: string } = storage.pinnedProfileIdsByPlaceKey or {}
		local pinnedProfileId = pinnedProfileIdsByPlaceKey[currentPlaceKey]
		if pinnedProfileId == nil then
			return
		end

		local customProfiles = storage.customProfiles or {}
		if not presets[pinnedProfileId] and not customProfiles[pinnedProfileId] then
			localStorage.setStorage(function(prev)
				local latestPinnedProfileIdsByPlaceKey: { [string]: string } = prev.pinnedProfileIdsByPlaceKey or {}
				if latestPinnedProfileIdsByPlaceKey[currentPlaceKey] ~= pinnedProfileId then
					return prev
				end

				local new = table.clone(prev)
				local newPinnedProfileIdsByPlaceKey = table.clone(latestPinnedProfileIdsByPlaceKey)
				newPinnedProfileIdsByPlaceKey[currentPlaceKey] = nil
				new.pinnedProfileIdsByPlaceKey = newPinnedProfileIdsByPlaceKey
				return new
			end)
			return
		end

		if getActiveProfileId() ~= pinnedProfileId then
			setSelectedProfileId(pinnedProfileId, false)
		end
	end)

	local getAllProfiles = computed(function(): { [string]: Profile }
		local all: { [string]: Profile } = {}

		for id, preset in presets do
			all[id] = wrapPreset(preset)
		end

		local customProfiles: CustomProfiles = localStorage.getStorage().customProfiles or {}
		for id, custom in customProfiles do
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

		local activeProfileId = getActiveProfileId()
		local storage = localStorage.getStorage()
		local customProfiles: CustomProfiles = storage.customProfiles or {}
		local activeCustomProfile = customProfiles[activeProfileId]

		local profile: Profile?
		if presets[activeProfileId] then
			profile = wrapPreset(presets[activeProfileId])
		elseif activeCustomProfile then
			profile = wrapCustomProfile(activeCustomProfile)
		else
			profile = wrapPreset(presets.default)
		end

		local overridePlaceId = if activeCustomProfile then activeCustomProfile.activity.overridePlaceId else nil
		if profile == nil then
			setResolvedActivity(nil)
			return
		end

		local placeContext: PlaceDetailsStore.PlaceContext?
		if overridePlaceId and overridePlaceId > 0 then
			placeDetailsStore.prefetchPlaceIds({ overridePlaceId })
			placeContext = placeDetailsStore.getContextByPlaceId(overridePlaceId)
		else
			placeContext = placeDetailsStore.getCurrentContext()
		end

		if placeContext == nil then
			setResolvedActivity(nil)
			return
		end

		local buildContext: BuildContext = {
			place = placeContext,
			studio = pluginContextStore.getStudioContext(),
		}

		local startedAt = presenceManager.getSessionStartedAt()

		buildThread = task.spawn(function()
			local activity = buildWithRetry(profile, buildContext)
			if activity then
				activity.startedAt = startedAt
			end
			setResolvedActivity(activity)
			buildThread = nil
		end)
	end)

	local disposePrefetchEffect = effect(function()
		local customProfiles: CustomProfiles = localStorage.getStorage().customProfiles or {}
		local placeIds: { number } = {}

		for _, custom in customProfiles do
			local overridePlaceId = custom.activity.overridePlaceId
			if overridePlaceId and overridePlaceId > 0 then
				table.insert(placeIds, overridePlaceId)
			end
		end

		if #placeIds > 0 then
			placeDetailsStore.prefetchPlaceIds(placeIds)
		end
	end)

	local function setCustomProfile(id: string, data: CustomProfileData)
		localStorage.setStorage(function(prev)
			local new = table.clone(prev)
			local customProfiles = table.clone(prev.customProfiles or {})
			customProfiles[id] = data
			new.customProfiles = customProfiles
			return new
		end)
	end

	local function removeCustomProfile(id: string)
		-- If the removed profile was active, fall back to default
		if peek(getActiveProfileId) == id then
			setSelectedProfileId("default", false)
		end

		localStorage.setStorage(function(prev)
			local new = table.clone(prev)
			local customProfiles = table.clone(prev.customProfiles or {})
			customProfiles[id] = nil
			new.customProfiles = customProfiles

			local pinnedProfileIdsByPlaceKey: { [string]: string } = prev.pinnedProfileIdsByPlaceKey or {}
			local newPinnedProfileIdsByPlaceKey = table.clone(pinnedProfileIdsByPlaceKey)
			local didRemovePinnedProfile = false
			for placeKey, pinnedProfileId in pinnedProfileIdsByPlaceKey do
				if pinnedProfileId == id then
					newPinnedProfileIdsByPlaceKey[placeKey] = nil
					didRemovePinnedProfile = true
				end
			end

			if didRemovePinnedProfile then
				new.pinnedProfileIdsByPlaceKey = newPinnedProfileIdsByPlaceKey
			end

			return new
		end)
	end

	local function destroy()
		disposeProfileFallbackEffect()
		disposeApplyPinnedProfileEffect()
		disposeBuildEffect()
		disposePrefetchEffect()

		if buildThread then
			pcall(task.cancel, buildThread)
			buildThread = nil
		end
	end

	return {
		getActiveProfileId = getActiveProfileId,
		getActiveProfile = getActiveProfile,
		getAllProfiles = getAllProfiles,
		getResolvedActivity = getResolvedActivity,
		getCurrentPlaceKey = getCurrentPlaceKey,
		getPinnedProfileIdForCurrentPlace = getPinnedProfileIdForCurrentPlace,
		getIsCurrentPlacePinned = getIsCurrentPlacePinned,

		setActiveProfile = setActiveProfile,
		pinCurrentPlaceToProfile = pinCurrentPlaceToProfile,
		unpinCurrentPlace = unpinCurrentPlace,
		toggleCurrentPlacePin = toggleCurrentPlacePin,
		setCustomProfile = setCustomProfile,
		removeCustomProfile = removeCustomProfile,

		destroy = destroy,
	}
end

return createProfileStore
