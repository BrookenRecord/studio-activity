local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(script.Parent.createPluginSettingsStore)

export type LocalStorageStore = {
	wasUserPromptedForTelemetry: boolean,
}

local defaultValue: LocalStorageStore = {
	wasUserPromptedForTelemetry = false,
}

local validate = t.interface({
	wasUserPromptedForTelemetry = t.boolean,
})

return {
	get = Charm.computed(function()
		return createPluginSettingsStore("PresenceLocalStorage", defaultValue, validate)
	end),
}
