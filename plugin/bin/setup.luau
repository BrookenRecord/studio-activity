local RunService = game:GetService("RunService")
local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local Telemetry = require(Plugin.Source.Telemetry.fireEventAsync)
local Types = require(Plugin.Source.Telemetry.Types)
local createPluginLoader = require(script.Parent.createPluginLoader)

export type PluginMain = (plugin: Plugin, pluginLoaderContext: createPluginLoader.PluginLoaderContext) -> () -> ()

local function setup(plugin: Plugin, main: PluginMain)
	plugin.Name = "StudioActivity"

	-- Currently, the plugin breaks in weird ways when running in Play Solo.
	-- While I come up with a better long-term solution, we're just going to
	-- block the plugin from running if we're in an active DataModel.
	-- See: https://github.com/grilme99/studio-activity/issues/6
	if RunService:IsRunning() then
		return
	end

	-- Derive dev-mode globals from BuildVars before any module that reads them
	local BuildVars = require(Plugin.Source.BuildVars)
	_G.__DEV__ = BuildVars.build.isDev
	_G.__LOG_LEVEL__ = if BuildVars.build.isDev then "info" else "warn"

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

	-- Fire PluginLoaded with current user state so PostHog can track
	-- active users and keep person properties up to date each session.
	local AuthStore = require(Plugin.Source.Authentication.AuthStore)
	local authStorage = AuthStore.get().getStorage()
	local accountCount = 0
	for _ in authStorage.accounts do
		accountCount += 1
	end

	-- We don't want to report custom profile names to telemetry, only built-in
	-- profiles.
	local activeProfile = profileStore.getActiveProfile()
	local activeProfileName = if activeProfile == nil
		then "unknown"
		elseif activeProfile.isPreset then activeProfile.name
		else "custom"

	Telemetry.fireEvent({
		type = "pluginLoaded",
		value = Types.PluginLoaded.new({
			accountCount = accountCount,
			isPresenceActive = presenceManager.getIsActive(),
			activeProfile = activeProfileName,
		}),
	})

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

	-- Single ordered cleanup handler for the entire plugin lifecycle.
	-- Order: unmount UI → dispose effects → destroy services → destroy loader.
	local destroyMain: (() -> ())? = nil

	plugin.Unloading:Connect(function()
		Telemetry.fireEvent({
			type = "pluginUnloaded",
			value = Types.PluginUnloaded.new(),
		})
		Telemetry.flushAll()

		if destroyMain then
			destroyMain()
		end
		disposeProfileEffect()
		profileStore.destroy()
		presenceManager.destroy()
		pluginLoaderContext.destroy()
	end)

	local success = pluginLoaderContext.waitForUserInteraction()
	if not success then
		return
	end

	destroyMain = main(plugin, pluginLoaderContext)
end

return setup
