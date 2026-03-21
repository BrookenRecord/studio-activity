local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local React = require(Packages.React)

local MainScreen = require(Plugin.Source.MainScreen)
local PluginLoader = require(Plugin.Bin.PluginLoader)
local PluginWidget = require(script.Parent.PluginWidget)
local TelemetryOptOutDialog = require(Plugin.Source.Telemetry.TelemetryOptOutDialog)

local e = React.createElement
local useCallback = React.useCallback
local useState = React.useState
local useEffect = React.useEffect

type Props = {
	pluginLoaderContext: PluginLoader.PluginLoaderContext,
}

local function PluginApp(props: Props)
	local enabled, setEnabled = useState(true)

	local toggleEnabled = useCallback(function()
		setEnabled(function(prev)
			return not prev
		end)
	end, {})

	local onClose = useCallback(function()
		setEnabled(false)
	end, {})

	local onRestore = useCallback(function(restoreEnabled: boolean)
		setEnabled(restoreEnabled)
	end, {})

	local onWidgetEnabledChanged = useCallback(function(nowEnabled: boolean)
		setEnabled(nowEnabled)
	end, {})

	useEffect(function()
		local connection
		task.delay(0, function()
			connection = props.pluginLoaderContext.mainButtonClickedSignal:Connect(toggleEnabled)
		end)
		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { props.pluginLoaderContext })

	return e(PluginWidget, {
		dockWidget = props.pluginLoaderContext.mainDockWidget :: DockWidgetPluginGui,
		enabled = enabled,
		zIndexBehavior = Enum.ZIndexBehavior.Sibling,
		onClose = onClose,
		onWidgetRestored = onRestore,
		onEnabledChanged = onWidgetEnabledChanged,
	}, {
		TelemetryOptOutDialog = React.createElement(TelemetryOptOutDialog),
		MainScreen = e(MainScreen),
	})
end

return PluginApp
