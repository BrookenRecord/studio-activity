local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createProfileStore = require(script.createProfileStore)

export type ProfileStore = createProfileStore.ProfileStore
export type Profile = createProfileStore.Profile
export type CustomProfileData = createProfileStore.CustomProfileData

return table.freeze({
	get = Charm.computed(function()
		return createProfileStore()
	end),
})
