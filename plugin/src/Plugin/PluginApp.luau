local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local MainScreen = require(Plugin.Source.MainScreen)
local ModalRenderer = require(Plugin.Source.Modal.ModalRenderer)
local ModalStore = require(Plugin.Source.Modal.ModalStore)
local NotificationsContainer = require(Plugin.Source.Notification.NotificationsContainer)
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

	useEffect(function()
		local storage = LocalStorageStore.get().getStorage()
		if not storage.hasCompletedOnboarding then
			ModalStore.get().open("welcome")
		end
	end, {})

	return e(PluginWidget, {
		dockWidget = props.pluginLoaderContext.mainDockWidget :: DockWidgetPluginGui,
		enabled = enabled,
		zIndexBehavior = Enum.ZIndexBehavior.Sibling,
		onClose = onClose,
		onWidgetRestored = onRestore,
		onEnabledChanged = onWidgetEnabledChanged,
	}, {
		NotificationsContainer = e(NotificationsContainer),
		ModalRenderer = e(ModalRenderer),
		MainScreen = e(MainScreen),
	})
end

return PluginApp
