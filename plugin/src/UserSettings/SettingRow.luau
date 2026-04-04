local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local Sift = require(Packages.Sift)

local DefaultSettings = require(script.Parent.DefaultSettings)
local UserSettingsStore = require(script.Parent.UserSettingsStore)

local View = Foundation.View
local Checkbox = Foundation.Checkbox
local Dropdown = Foundation.Dropdown
local NumberInput = Foundation.NumberInput
local InputSize = Foundation.Enums.InputSize
local useTokens = Foundation.Hooks.useTokens

local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useCallback = React.useCallback
local useMemo = React.useMemo

type Setting = DefaultSettings.Setting
type SettingChoice = DefaultSettings.SettingChoice

type Props = {
	setting: Setting,
	LayoutOrder: number?,
}

local function SettingRow(props: Props)
	local tokens = useTokens()

	local userSettingsStore = UserSettingsStore.get()
	local userSettings = useSignalState(userSettingsStore.getStorage)

	local setSetting = useCallback(function(newValue: any)
		userSettingsStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				[props.setting.name] = newValue,
			})
		end)
	end, { userSettingsStore.setStorage :: any, props.setting })

	local optionElement = useMemo(function(): React.Node
		local value = userSettings[props.setting.name]

		if props.setting.settingType == "checkbox" then
			return e(Checkbox, {
				label = props.setting.displayName,
				hint = props.setting.description,
				size = InputSize.Small,
				isChecked = value,
				onActivated = setSetting,
			})
		elseif props.setting.settingType == "dropdown" then
			local items = Sift.List.map(props.setting.choices, function(choice: SettingChoice): Foundation.DropdownItem
				return {
					id = choice.name,
					text = choice.displayName,
				}
			end)

			return e(Dropdown.Root, {
				label = props.setting.displayName,
				hint = props.setting.description,
				size = InputSize.Small,
				width = UDim.new(1, 0),
				value = value,
				items = items,
				onItemChanged = setSetting,
			})
		elseif props.setting.settingType == "number" then
			local range = props.setting.range

			return e(NumberInput, {
				value = value,
				label = props.setting.displayName,
				hint = props.setting.description,
				size = InputSize.Small,
				step = 10,
				maximum = if range then range.Max else nil,
				minimum = if range then range.Min else nil,
				onChanged = setSetting,
			})
		end
		error(`no handling for setting type {props.setting.settingType}`)
	end, { props.setting :: any, setSetting, userSettings })

	local hasBeenChanged = not userSettingsStore.isSettingDefault(props.setting.name)

	return e(View, {
		tag = "size-full-0 auto-y",
		LayoutOrder = props.LayoutOrder,
	}, {
		ChangedIndicator = if hasBeenChanged
			then e(View, {
				tag = "size-50-full",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(-8, 0),
				backgroundStyle = tokens.Color.System.Emphasis,
			})
			else nil,

		OptionWrapper = e(View, {
			tag = "size-full-0 auto-y",
		}, {
			Option = optionElement,
		}),
	})
end

return React.memo(SettingRow)
