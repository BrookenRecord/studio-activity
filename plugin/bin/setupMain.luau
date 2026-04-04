local Plugin = script:FindFirstAncestor("StudioActivity")

local createPluginLoader = require(script.Parent.createPluginLoader)

-- The main function runs when the plugin is opened for the first time.
-- Returns a cleanup function to be called during plugin unload.
local function main(plugin: Plugin, pluginLoaderContext: createPluginLoader.PluginLoaderContext): () -> ()
	local createPresencePlugin = require(Plugin.Source.Plugin.createPresencePlugin)
	local presencePlugin = createPresencePlugin(plugin, pluginLoaderContext)

	presencePlugin.mount()

	return function()
		presencePlugin.destroy()
	end
end

return main
