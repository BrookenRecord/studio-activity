local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(Plugin.Source.Plugin.createPluginSettingsStore)

export type Account = {
	accessToken: string,
	refreshToken: string,
	--- Timestamp in the future for when we need to refresh the access token.
	expiresAt: number,
}

export type AuthStore = {
	-- Keyed by Discord account ID
	accounts: { [string]: Account },
}

local defaultValue: AuthStore = {
	accounts = {},
}

local validate = t.interface({
	accounts = t.strictArray(t.strictInterface({
		accessToken = t.string,
		refreshToken = t.string,
	})),
})

return {
	get = Charm.computed(function()
		return createPluginSettingsStore<<AuthStore>>("PresenceAuthStore", defaultValue, validate)
	end),
}
