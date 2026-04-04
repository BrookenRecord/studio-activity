local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local DefaultSettings = require(script.Parent.DefaultSettings)
local SettingRow = require(script.Parent.SettingRow)

local View = Foundation.View
local Text = Foundation.Text

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement
local useMemo = React.useMemo

type Setting = DefaultSettings.Setting
type SettingChoice = DefaultSettings.SettingChoice

type SettingsGroup = {
	name: string,
	settings: { Setting },
}

local function SettingsView()
	local nextOrder = createNextOrder()

	local settingsByGroup: { SettingsGroup } = useMemo(function()
		local settings = Sift.Dictionary.values(DefaultSettings)

		local sorted = Sift.Array.sort(settings, function(a: Setting, b: Setting)
			return a.name < b.name
		end)

		local groups = Sift.Array.reduce(sorted, function(accumulator: { [string]: SettingsGroup }, setting: Setting)
			local group: SettingsGroup
			if accumulator[setting.group] then
				group = accumulator[setting.group]
			else
				group = {
					name = setting.group,
					settings = {},
				}
				accumulator[setting.group] = group
			end

			table.insert(group.settings, setting)

			return accumulator
		end, {})

		return Sift.Array.sort(Sift.Dictionary.values(groups), function(a: SettingsGroup, b: SettingsGroup)
			return a.name < b.name
		end)
	end, { DefaultSettings })

	local children: { [string]: React.Node } = {}
	for index, group in settingsByGroup do
		local isFirst = index == 1
		children[group.name] = e(Text, {
			tag = {
				["auto-xy text-title-large padding-bottom-medium"] = true,
				["padding-top-medium"] = not isFirst,
			},
			Text = group.name,
			LayoutOrder = nextOrder(),
		})

		for _, setting in group.settings do
			children[setting.name] = e(SettingRow, {
				setting = setting,
				LayoutOrder = nextOrder(),
			})
		end
	end

	return e(View, {
		tag = "size-full-0 auto-y col padding-bottom-medium",
	}, children)
end

return React.memo(SettingsView)
