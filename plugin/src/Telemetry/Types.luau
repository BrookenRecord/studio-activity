--[[
	Re-exports protobuf-generated telemetry event constructors.

	Callers use this module instead of importing from the codegen path directly:

		local Types = require(Telemetry.Types)
		local event = { type = "pluginLoaded", value = Types.PluginLoaded.new({ ... }) }
]]

local Plugin = script:FindFirstAncestor("StudioActivity")
local api = require(Plugin.Source.Api.Protos.api.v1.api)

export type AccountLinkFlow = api.AccountLinkFlow

export type TelemetryEvent =
	{ type: "pluginLoaded", value: api.PluginLoaded }
	| { type: "uiOpened", value: api.UiOpened }
	| { type: "onboardingCompleted", value: api.OnboardingCompleted }
	| { type: "accountLinkStarted", value: api.AccountLinkStarted }
	| { type: "accountLinked", value: api.AccountLinked }
	| { type: "deviceCodeFlowFailed", value: api.DeviceCodeFlowFailed }
	| { type: "browserFlowFailed", value: api.BrowserFlowFailed }
	| { type: "accountRemoved", value: api.AccountRemoved }
	| { type: "presenceToggled", value: api.PresenceToggled }
	| { type: "profileSelected", value: api.ProfileSelected }
	| { type: "sessionError", value: api.SessionError }
	| { type: "pluginUnloaded", value: api.PluginUnloaded }

return table.freeze({
	AccountLinkFlow = api.AccountLinkFlow,
	PluginLoaded = api.PluginLoaded,
	UiOpened = api.UiOpened,
	OnboardingCompleted = api.OnboardingCompleted,
	AccountLinkStarted = api.AccountLinkStarted,
	AccountLinked = api.AccountLinked,
	DeviceCodeFlowFailed = api.DeviceCodeFlowFailed,
	BrowserFlowFailed = api.BrowserFlowFailed,
	AccountRemoved = api.AccountRemoved,
	PresenceToggled = api.PresenceToggled,
	ProfileSelected = api.ProfileSelected,
	SessionError = api.SessionError,
	PluginUnloaded = api.PluginUnloaded,
})
