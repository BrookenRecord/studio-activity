local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Log = require(Packages.Log)

local function stringToLogLevel(logLevel: string)
	if logLevel == "info" then
		return Log.LogLevel.Information
	elseif logLevel == "warn" or logLevel == "warning" then
		return Log.LogLevel.Warning
	elseif logLevel == "debug" then
		return Log.LogLevel.Debugging
	elseif logLevel == "err" or logLevel == "error" then
		return Log.LogLevel.Error
	end
	return Log.LogLevel.Warning
end

local sinks = {}
if _G.__DEV__ then
	table.insert(sinks, Log.Common.RobloxLogSink())
end

local logger = Log.Logger.new(
	{
		Log.Common.Enrichers.LogLevelEnricher(),
		Log.Common.Enrichers.DynSourceEnricher(true),
	},
	sinks,
	{
		Log.Common.Filters.MinLevelFilter(stringToLogLevel(_G.__LOG_LEVEL__)),
	}
)

return logger
