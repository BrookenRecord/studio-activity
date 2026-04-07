local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local BackendApi = require(Plugin.Source.Api.Backend)
local BuildVars = require(Plugin.Source.BuildVars)
local Debounce = require(Plugin.Source.Common.Debounce)
local Logger = require(Plugin.Source.Logger)
local Types = require(script.Parent.Types)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)
local api = require(Plugin.Source.Api.Protos.api.v1.api)
local getAnonymizedUserId = require(script.Parent.getAnonymizedUserId)

type TelemetryEvent = Types.TelemetryEvent

-- Lazy-initialized module state (created on first fireEvent call)
local backendApi: BackendApi.BackendApi? = nil
local sessionId: string? = nil
local distinctId: string? = nil

local function ensureInitialized()
	if backendApi then
		return
	end

	backendApi = BackendApi.new(BuildVars.api)
	sessionId = HttpService:GenerateGUID(false)
	distinctId = getAnonymizedUserId()
end

-- Events with trailing-edge debounce (seconds). Only the final state
-- within the window is sent, preventing floods from rapid toggling.
local DEBOUNCE_EVENTS: { [string]: number } = {
	presenceToggled = 2,
	profileSelected = 2,
}

local debouncedSenders: { [string]: Debounce.DebouncedFn } = {}

local function sendEvent(event: TelemetryEvent)
	ensureInitialized()
	assert(backendApi and sessionId and distinctId)

	local request = api.TelemetryRequest.new({
		distinctId = distinctId,
		sessionId = sessionId,
		pluginVersion = BuildVars.build.version,
		pluginChannel = BuildVars.build.channel,
		pluginHash = BuildVars.build.hash,
		event = event,
	})

	local result = backendApi.captureTelemetryAsync(request)
	if not result.ok then
		Logger:Warn(`telemetry send failed: {result.error.type}`)
	end
end

--[[
	Fire a telemetry event. Respects the user's opt-out setting.

	The event is sent to the backend asynchronously (fire-and-forget).
	High-frequency events like presence_toggled and profile_selected
	are debounced so only the final state is sent.
]]
local function fireEvent(event: TelemetryEvent)
	local userSettingsStore = UserSettingsStore.get()
	local userSettings = userSettingsStore.getStorage()

	if not userSettings.collectAnonymousUsageData then
		return
	end

	if event == nil then
		return
	end

	local eventType = event.type

	local debounceSeconds = DEBOUNCE_EVENTS[eventType]
	if debounceSeconds then
		local debounced = debouncedSenders[eventType]
		if not debounced then
			debounced = Debounce.trailing(debounceSeconds, function(debouncedEvent: TelemetryEvent)
				task.spawn(sendEvent, debouncedEvent)
			end)
			debouncedSenders[eventType] = debounced
		end
		debounced.call(event)
	else
		task.spawn(sendEvent, event)
	end
end

--[[
	Flush all pending debounced events immediately.
	Call this during plugin teardown to ensure final state is sent.
]]
local function flushAll()
	for _, debounced in debouncedSenders do
		debounced.flush()
	end
end

return table.freeze({
	fireEvent = fireEvent,
	flushAll = flushAll,
})
