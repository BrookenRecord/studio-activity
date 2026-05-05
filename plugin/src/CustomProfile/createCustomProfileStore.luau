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
		details = "Building my game",
		state = "{placeName}",
		showPlaceIcon = true,
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

export type CustomProfileStore = {
	getProfile: () -> CustomProfileData,
	setProfile: (CustomProfileData | (CustomProfileData) -> CustomProfileData) -> CustomProfileData,
	getOverrideLookupState: () -> OverrideLookupState,
	setOverrideLookupInput: (input: string) -> (),

	isChanged: () -> boolean,
	save: () -> (),
	delete: () -> (),
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
		local normalizedInput = if input == "0" then "" else input
		setLookupInput(normalizedInput)
		local trimmed = normalizedInput:match("^%s*(.-)%s*$")

		if trimmed == "" then
			debouncedLookup.cancel()
			setLookupPlaceId(nil)
			setLookupError(nil)
			persistPlaceOverride(nil)
			return
		end

		local placeId = tonumber(trimmed)
		if not placeId or placeId <= 0 then
			debouncedLookup.cancel()
			setLookupPlaceId(nil)
			setLookupError("invalid_place_id")
			persistPlaceOverride(nil)
			return
		end

		setLookupError(nil)
		setLookupPlaceId(nil)
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

	local function save()
		debouncedLookup.flush()
		LocalStorageStore.get().setStorage(function(prev)
			local new = table.clone(prev)

			local customProfiles: LocalStorageStore.CustomProfiles = if new.customProfiles
				then table.clone(new.customProfiles)
				else {}

			customProfiles[profileId] = getProfile()

			new.customProfiles = customProfiles
			return new
		end)

		ProfileStore.get().setActiveProfile(profileId)
	end

	local function delete()
		LocalStorageStore.get().setStorage(function(prev)
			local new = table.clone(prev)

			local customProfiles: LocalStorageStore.CustomProfiles = if new.customProfiles
				then table.clone(new.customProfiles)
				else {}

			customProfiles[profileId] = nil

			new.customProfiles = customProfiles
			return new
		end)
	end

	return {
		getProfile = getProfile,
		setProfile = setProfile,
		getOverrideLookupState = getOverrideLookupState,
		setOverrideLookupInput = setOverrideLookupInput,

		isChanged = isChanged,
		save = save,
		delete = delete,
	}
end

return createCustomProfileStore
