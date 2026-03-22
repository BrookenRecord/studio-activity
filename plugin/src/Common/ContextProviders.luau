local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local PluginStore = require(Plugin.Source.Plugin.PluginStore)
local useThemeName = require(script.Parent.useThemeName)

local FoundationProvider = Foundation.FoundationProvider

local e = React.createElement
local useEffect = React.useEffect

type Props = {
	plugin: Plugin,
	overlayGui: GuiBase2d?,

	_TESTING_themeOverride: Foundation.Theme?,

	children: React.ReactNode,
}

local function ContextProviders(props: Props)
	local themeName: useThemeName.ThemeName = useThemeName()

	useEffect(function()
		PluginStore.get().setPlugin(props.plugin)
	end, { props.plugin })

	return e(ReactUtils.ContextStack, {
		providers = {
			e(FoundationProvider, {
				theme = props._TESTING_themeOverride or themeName,
				overlayGui = props.overlayGui,
			}),
		},
	}, props.children)
end

return ContextProviders
