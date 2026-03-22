local Plugin = script:FindFirstAncestor("StudioActivity")

local Logger = require(Plugin.Source.Logger)
local Types = require(script.Parent.Types)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)
local getAnonymizedUserId = require(script.Parent.getAnonymizedUserId)

type TelemetryEvent = Types.TelemetryEvent

local function fireEventAsync(event: TelemetryEvent)
	local userSettingsStore = UserSettingsStore.get(false)
	local userSettings = userSettingsStore.getStorage(false)

	if not userSettings.collectAnonymousUsageData then
		return
	end

	local _body = {
		eventName = event.eventName,
		properties = (event :: any).properties,
		anonymizedUserId = getAnonymizedUserId(),
		-- buildVersion = _G.BUILD_VERSION,
		-- buildChannel = _G.BUILD_CHANNEL,
		-- buildHash = _G.BUILD_HASH,
	}

	Logger:Info(`firing event {event.eventName}`)

	-- return requestAsync(`{_G.BASE_URL}/telemetry`, {
	-- 	method = "POST",
	-- 	body = body,
	-- })
end

return fireEventAsync
