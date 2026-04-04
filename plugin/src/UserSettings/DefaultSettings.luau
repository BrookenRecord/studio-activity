export type SettingType = "checkbox" | "dropdown" | "number"

local SettingType = {
	Checkbox = "checkbox" :: "checkbox",
	Dropdown = "dropdown" :: "dropdown",
	Number = "number" :: "number",
}

export type SettingGroup = "UI" | "Telemetry"

local SettingGroup = {
	UI = "UI" :: SettingGroup,
	Telemetry = "Telemetry" :: SettingGroup,
}

export type SettingChoice = {
	description: string,
	displayName: string,
	name: string,
}

type BaseSetting = {
	name: string,
	group: SettingGroup,
	displayName: string,
	description: string,
	settingType: SettingType,
}

type CheckboxSetting = BaseSetting & {
	settingType: "checkbox",
	value: boolean,
}

type DropdownSetting = BaseSetting & {
	settingType: "dropdown",
	choices: { SettingChoice },
}

type NumberSetting = BaseSetting & {
	settingType: "number",
	range: NumberRange?,
	value: number,
}

export type Setting = CheckboxSetting | DropdownSetting | NumberSetting

local theme: DropdownSetting = {
	name = "theme",
	group = SettingGroup.UI,
	displayName = "UI theme",
	description = "Select the UI theme to use. By default, Studio Activity will use the same theme as Studio",
	settingType = SettingType.Dropdown,
	choices = {
		{
			name = "system",
			displayName = "System",
			description = "Match the theme selected for Studio",
		},
		{
			name = "dark",
			displayName = "Dark",
			description = "Force the theme to use dark mode",
		},
		{
			name = "light",
			displayName = "Light",
			description = "Force the theme to use light mode",
		},
	},
}

local collectAnonymousUsageData: CheckboxSetting = {
	name = "collectAnonymousUsageData",
	group = SettingGroup.Telemetry,
	displayName = "Help improve Studio Activity by sending anonymous usage data",
	description = "Allow Studio Activity to collect anonymous usage data to help improve the product. No personal data is collected",
	settingType = SettingType.Checkbox,
	value = true,
}

local settings = {
	theme = theme,
	collectAnonymousUsageData = collectAnonymousUsageData,
}

export type Settings = typeof(settings)

return settings
