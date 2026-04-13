local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
export type CustomProfileData = LocalStorageStore.CustomProfileData

local signal = Charm.signal

local DEFAULT_CUSTOM_PROFILE: CustomProfileData = {
	name = "My Profile",
	activity = {
		details = "Building my game",
		state = "{placeName}",
		showPlaceIcon = true,
	},
}

export type CustomProfileStore = {
	getProfile: () -> CustomProfileData,
	setProfile: (CustomProfileData | (CustomProfileData) -> CustomProfileData) -> CustomProfileData,

	save: () -> (),
}

local function createCustomProfileStore(existingProfileId: string?): CustomProfileStore
	local profileId = existingProfileId or HttpService:GenerateGUID()

	local function getExistingProfile(): CustomProfileData?
		local localStorage = LocalStorageStore.get().getStorage()
		return localStorage.customProfiles and localStorage.customProfiles[profileId]
	end

	local getProfile, setProfile = signal<<CustomProfileData>>(getExistingProfile() or DEFAULT_CUSTOM_PROFILE)

	local function save()
		LocalStorageStore.get().setStorage(function(prev)
			local new = table.clone(prev)

			local customProfiles: LocalStorageStore.CustomProfiles = if new.customProfiles
				then table.clone(new.customProfiles)
				else {}

			customProfiles[profileId] = getProfile()

			new.customProfiles = customProfiles
			return new
		end)
	end

	return {
		getProfile = getProfile,
		setProfile = setProfile,

		save = save,
	}
end

return createCustomProfileStore
