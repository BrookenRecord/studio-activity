local createProfileStore = require(script.createProfileStore)

export type ProfileStore = createProfileStore.ProfileStore
export type Profile = createProfileStore.Profile

local instance = nil

local function get()
	if not instance then
		instance = createProfileStore()
	end
	return instance
end

return table.freeze({ get = get })
