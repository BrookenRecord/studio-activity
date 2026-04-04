local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local t = require(Packages.t)

local createPluginSettingsStore = require(Plugin.Source.Plugin.createPluginSettingsStore)
local defaultSettings = require(script.Parent.DefaultSettings)

export type UserSettings = {
	theme: string,
	collectAnonymousUsageData: boolean,
}

local defaultValue: UserSettings = {
	theme = defaultSettings.theme.choices[1].name,
	collectAnonymousUsageData = defaultSettings.collectAnonymousUsageData.value,
}

local validate = t.interface({
	theme = t.string,
	collectAnonymousUsageData = t.boolean,
})

-- defaultValue needs to be kept in sync with the keys in defaultSettings
for key in defaultSettings do
	assert(defaultValue[key] ~= nil, `setting with key {key} is missing from UserSettingsStore`)
end

return {
	get = Charm.computed(function()
		return createPluginSettingsStore("PresenceUserSettings", defaultValue, validate)
	end),
}
