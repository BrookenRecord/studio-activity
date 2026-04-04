local Plugin = script:FindFirstAncestor("StudioActivity")

local Logger = require(Plugin.Source.Logger)
local Types = require(script.Parent.Types)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)

type TelemetryEvent = Types.TelemetryEvent

--[[
	Fire a telemetry event. Respects the user's opt-out setting.

	TODO: Wire up HTTP transport once the backend telemetry endpoint exists.
	The event payload should include: eventName, properties (if any),
	anonymizedUserId, build version/channel/hash, and a timestamp.
]]
local function fireEvent(event: TelemetryEvent)
	local userSettingsStore = UserSettingsStore.get()
	local userSettings = userSettingsStore.getStorage()

	if not userSettings.collectAnonymousUsageData then
		return
	end

	Logger:Info(`telemetry event: {event.eventName}`)
end

return fireEvent
