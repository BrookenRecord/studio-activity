local Plugin = script:FindFirstAncestor("StudioActivity")

local createPluginLoader = require(script.Parent.createPluginLoader)

-- The main function runs when the plugin is opened for the first time
local function main(plugin: Plugin, pluginLoaderContext: createPluginLoader.PluginLoaderContext)
	-- TODO: Best way to toggle this?
	_G.__DEV__ = true
	_G.__LOG_LEVEL__ = "info"

	local createPresencePlugin = require(Plugin.Source.Plugin.createPresencePlugin)
	local presencePlugin = createPresencePlugin(plugin, pluginLoaderContext)

	presencePlugin.mount()

	plugin.Unloading:Connect(function()
		presencePlugin.destroy()
	end)
end

return main
