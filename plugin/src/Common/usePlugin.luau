local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local ReactCharm = require(Packages.ReactCharm)

local PluginStore = require(Plugin.Source.Plugin.PluginStore)

local function usePlugin(): Plugin
	local pluginStore = ReactCharm.useSignalState(PluginStore.get)
	local plugin = pluginStore.getPlugin()
	if plugin == nil then
		error("Plugin not found")
	end
	return plugin
end

return usePlugin
