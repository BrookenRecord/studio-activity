local Plugin = script:FindFirstAncestor("StudioRichPresence")

local createPluginLoader = require(script.Parent.createPluginLoader)

export type PluginMain = (plugin: Plugin, pluginLoaderContext: createPluginLoader.PluginLoaderContext) -> ()

local function setup(plugin: Plugin, main: PluginMain)
	plugin.Name = "StudioRichPresence"

	local pluginLoaderContext = createPluginLoader({
		plugin = plugin,
		pluginName = "StudioRichPresence",
		translationResourceTable = Plugin.Resources.LocalizedStrings,
		getToolbarName = function(localize): string
			return localize("Plugin", "ToolbarName")
		end,
		buttonInfo = {
			getName = function(localize): string
				return localize("Plugin", "Name")
			end,
			getDescription = function(localize): string
				return localize("Plugin", "Description")
			end,
			icon = "",
			enabled = true,
			clickableWhenViewportHidden = true,
		},
		dockWidgetInfo = {
			id = "StudioRichPresence",
			name = "StudioRichPresence",
			dockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo.new(
				Enum.InitialDockState.Right, --initialDockState,
				false, --initialEnabled,
				false, --initialEnabledShouldOverrideRestore,
				640, --size.X,
				480, --size.Y,
				250, --minSize.X,
				200 --minSize.Y
			),
			getDockTitle = function(localize): string
				return localize("Plugin", "Name")
			end,
			zIndexBehavior = Enum.ZIndexBehavior.Sibling,
		},
	})

	local success = pluginLoaderContext.waitForUserInteraction()
	if not success then
		return
	end

	main(plugin, pluginLoaderContext)
end

return setup
