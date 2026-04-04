local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createPluginLoader = require(script.Parent.createPluginLoader)

export type PluginMain = (plugin: Plugin, pluginLoaderContext: createPluginLoader.PluginLoaderContext) -> ()

local function setup(plugin: Plugin, main: PluginMain)
	plugin.Name = "StudioActivity"

	-- Set plugin instance early so settings stores can load auth from disk
	local PluginStore = require(Plugin.Source.Plugin.PluginStore)
	PluginStore.get().setPlugin(plugin)

	-- Start presence manager immediately, before user interacts with the plugin.
	-- This triggers: AuthStore loads from disk → PresenceManager reads accounts
	-- → creates headless sessions so linked users see presence right away.
	local PresenceManager = require(Plugin.Source.PresenceManager)
	local presenceManager = PresenceManager.get()

	-- Initialize ProfileStore early so it loads the active profile from disk
	-- and begins resolving it against PlaceContext.
	local ProfileStore = require(Plugin.Source.PresenceManager.ProfileStore)
	local profileStore = ProfileStore.get()

	-- Wire resolved activity from ProfileStore into PresenceManager
	local disposeProfileEffect = Charm.effect(function()
		presenceManager.setActivity(profileStore.getResolvedActivity())
	end)

	plugin.Unloading:Connect(function()
		disposeProfileEffect()
		profileStore.destroy()
		presenceManager.destroy()
	end)

	local pluginLoaderContext = createPluginLoader({
		plugin = plugin,
		pluginName = "StudioActivity",
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
			id = "StudioActivity",
			name = "StudioActivity",
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
