local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local t = require(Packages.t)

local createPluginSettingsStore = require(Plugin.Source.Plugin.createPluginSettingsStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)

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
	accounts = t.map(
		t.string,
		t.strictInterface({
			accessToken = t.string,
			refreshToken = t.string,
			expiresAt = t.number,
		})
	),
})

return {
	get = createSingleton(function()
		return createPluginSettingsStore("PresenceAuthStore", defaultValue, validate)
	end),
}
