local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local MainScreen = require(Plugin.Source.MainScreen)
local ModalRenderer = require(Plugin.Source.Modal.ModalRenderer)
local PluginWidget = require(script.Parent.PluginWidget)
local createPluginLoader = require(Plugin.Bin.createPluginLoader)

local e = React.createElement
local useCallback = React.useCallback
local useState = React.useState
local useEffect = React.useEffect

type Props = {
	pluginLoaderContext: createPluginLoader.PluginLoaderContext,
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
		local connection = props.pluginLoaderContext.mainButtonClickedSignal.Connect(toggleEnabled)
		return function()
			connection.Disconnect()
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
		ModalRenderer = e(ModalRenderer),
		MainScreen = e(MainScreen),
	})
end

return PluginApp
