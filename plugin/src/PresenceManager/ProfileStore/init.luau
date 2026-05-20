local Plugin = script:FindFirstAncestor("StudioActivity")

local createProfileStore = require(script.createProfileStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)

export type ProfileStore = createProfileStore.ProfileStore
export type Profile = createProfileStore.Profile

return table.freeze({
	get = createSingleton(createProfileStore),
})
