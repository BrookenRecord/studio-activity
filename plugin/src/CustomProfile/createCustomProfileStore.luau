local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Sift = require(Packages.Sift)

local Debounce = require(Plugin.Source.Common.Debounce)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local ProfileStore = require(Plugin.Source.PresenceManager.ProfileStore)

export type CustomProfileData = LocalStorageStore.CustomProfileData
type PlaceContext = PlaceDetailsStore.PlaceContext

local signal = Charm.signal
local computed = Charm.computed

local LOOKUP_DEBOUNCE_SECONDS = 1

local DEFAULT_CUSTOM_PROFILE: CustomProfileData = {
	name = "My Profile",
	activity = {
		details = "{placeName}",
		state = "Building my game",
		showPlaceIcon = true,
		showJoinButton = true,
		showPluginButton = false,
		showCurrentScript = true,
		showTestingState = true,
	},
}

export type OverrideLookupStatus = "idle" | "loading" | "ready" | "error"

export type OverrideLookupState = {
	input: string,
	placeId: number?,
	status: OverrideLookupStatus,
	context: PlaceContext?,
	error: string?,
}

export type SaveOptions = {
	activate: boolean?,
}

export type CustomProfileStore = {
	getProfile: () -> CustomProfileData,
	setProfile: (CustomProfileData | (CustomProfileData) -> CustomProfileData) -> CustomProfileData,
	getOverrideLookupState: () -> OverrideLookupState,
	setOverrideLookupInput: (input: string) -> (),

	isChanged: () -> boolean,
	save: (options: SaveOptions?) -> (),
	delete: () -> (),
	destroy: () -> (),
}

local function createCustomProfileStore(existingProfileId: string?): CustomProfileStore
	local profileId = existingProfileId or HttpService:GenerateGUID()

	local function getExistingProfile(): CustomProfileData?
		local localStorage = LocalStorageStore.get().getStorage()
		return localStorage.customProfiles and localStorage.customProfiles[profileId]
	end

	local getProfile, setProfile = signal<<CustomProfileData>>(getExistingProfile() or DEFAULT_CUSTOM_PROFILE)
	local placeDetailsStore = PlaceDetailsStore.get()

	local originalOverride = getProfile().activity.overridePlaceId
	local initialInput = if originalOverride and originalOverride > 0 then tostring(originalOverride) else ""

	-- Kick off a fetch for the saved override so the UI doesn't sit in a
	-- "loading" state when the editor reopens before the entry is cached.
	if originalOverride and originalOverride > 0 then
		placeDetailsStore.prefetchPlaceIds({ originalOverride })
	end

	local getLookupInput, setLookupInput = signal(initialInput)
	local getLookupPlaceId, setLookupPlaceId = signal(originalOverride)
	local getLookupError, setLookupError = signal(nil :: string?)

	local function persistPlaceOverride(placeId: number?)
		setProfile(function(prev)
			return Sift.Dictionary.mergeDeep(prev, {
				activity = {
					overridePlaceId = placeId or Sift.None,
				},
			})
		end)
	end

	local debouncedLookup = Debounce.trailing(LOOKUP_DEBOUNCE_SECONDS, function(placeId: number)
		placeDetailsStore.prefetchPlaceIds({ placeId })
		setLookupPlaceId(placeId)
		persistPlaceOverride(placeId)
	end)

	local function setOverrideLookupInput(input: string)
		local trimmed = input:match("^%s*(.-)%s*$") or ""
		local normalizedInput = if trimmed == "0" then "" else trimmed
		setLookupInput(normalizedInput)

		if normalizedInput == "" then
			debouncedLookup.cancel()
			setLookupPlaceId(nil)
			setLookupError(nil)
			persistPlaceOverride(nil)
			return
		end

		local placeId = tonumber(normalizedInput)
		if not placeId or placeId <= 0 then
			debouncedLookup.cancel()
			setLookupPlaceId(nil)
			setLookupError("invalid_place_id")
			persistPlaceOverride(nil)
			return
		end

		setLookupError(nil)

		-- Intentionally do NOT clear lookupPlaceId here; the previously-resolved
		-- place stays visible in the preview until the new lookup resolves,
		-- avoiding a 1s "loading" flash on every keystroke.
		debouncedLookup.call(placeId)
	end

	local getOverrideLookupState = computed(function(): OverrideLookupState
		local input = getLookupInput()
		local error = getLookupError()
		if error then
			return {
				input = input,
				status = "error",
				error = error,
			}
		end

		if input == "" then
			return {
				input = input,
				status = "idle",
			}
		end

		local placeId = getLookupPlaceId()
		if not placeId then
			return {
				input = input,
				status = "loading",
			}
		end

		local entry = placeDetailsStore.getPlaceEntry(placeId)
		if not entry or entry.status == "loading" then
			return {
				input = input,
				placeId = placeId,
				status = "loading",
			}
		end

		if entry.status == "error" then
			return {
				input = input,
				placeId = placeId,
				status = "error",
				error = entry.error or "fetch_failed",
			}
		end

		local context = placeDetailsStore.getContextByPlaceId(placeId)
		if not context then
			return {
				input = input,
				placeId = placeId,
				status = "loading",
			}
		end

		return {
			input = input,
			placeId = placeId,
			status = "ready",
			context = context,
		}
	end)

	local function isChanged(): boolean
		local storage = LocalStorageStore.get().getStorage()
		local customProfiles: LocalStorageStore.CustomProfiles = if storage.customProfiles
			then table.clone(storage.customProfiles)
			else {}

		local profile = getProfile()
		if customProfiles == nil or customProfiles[profileId] == nil then
			return not Sift.Dictionary.equalsDeep(profile, DEFAULT_CUSTOM_PROFILE)
		end

		return not Sift.Dictionary.equalsDeep(profile, customProfiles[profileId])
	end

	local function save(options: SaveOptions?)
		debouncedLookup.flush()

		local profileStore = ProfileStore.get()
		profileStore.setCustomProfile(profileId, getProfile())

		local shouldActivate = if options and options.activate ~= nil then options.activate else false
		if shouldActivate then
			profileStore.setActiveProfile(profileId)
		end
	end

	local function delete()
		debouncedLookup.cancel()
		ProfileStore.get().removeCustomProfile(profileId)
	end

	local function destroy()
		debouncedLookup.cancel()
	end

	return {
		getProfile = getProfile,
		setProfile = setProfile,
		getOverrideLookupState = getOverrideLookupState,
		setOverrideLookupInput = setOverrideLookupInput,

		isChanged = isChanged,
		save = save,
		delete = delete,
		destroy = destroy,
	}
end

return createCustomProfileStore
