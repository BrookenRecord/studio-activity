local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ContextProviders = require(Plugin.Source.Common.ContextProviders)
local Logger = require(Plugin.Source.Logger)
local createPluginLoader = require(Plugin.Bin.createPluginLoader)
local fireEvent = require(Plugin.Source.Telemetry.fireEventAsync)

local PluginApp = require(script.Parent.PluginApp)

local e = React.createElement

local function stopwatch(callback: () -> ()): string
	local start = os.clock()
	callback()
	return ("%.2fms"):format((os.clock() - start) * 1000)
end

local function createPresencePlugin(plugin: Plugin, pluginLoaderContext: createPluginLoader.PluginLoaderContext)
	local widget = pluginLoaderContext.mainDockWidget
	assert(widget ~= nil, "Main dock widget not found")

	local root = ReactRoblox.createRoot(widget)
	local app = e(ContextProviders, {
		plugin = plugin,
		overlayGui = widget :: GuiBase2d,
	}, {
		App = e(PluginApp, {
			pluginLoaderContext = pluginLoaderContext,
		}),
	})

	local function unmount()
		Logger:Info("unmounting app...")
		local elapsedMs = stopwatch(function()
			root:unmount()
		end)
		Logger:Info(`unmounted app in {elapsedMs}`)

		fireEvent({ eventName = "AppClosed" })
	end

	local function mount()
		Logger:Info("mounting app...")
		local elapsedMs = stopwatch(function()
			root:render(app)
		end)
		Logger:Info(`mounted app in {elapsedMs}`)

		fireEvent({ eventName = "AppOpened" })
	end

	local function destroy()
		Logger:Info("destroying app...")
		local elapsedMs = stopwatch(function()
			unmount()
		end)
		Logger:Info(`destroyed app in {elapsedMs}`)
	end

	return {
		mount = mount,
		unmount = unmount,
		destroy = destroy,
	}
end

return createPresencePlugin
