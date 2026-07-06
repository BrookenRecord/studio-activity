local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)

--[[
	The events we send to the backend need some persistent identifier so we can
	group them by install. Keep this value independent from Roblox account IDs
	so it cannot be reversed or joined back to a public user id.
]]
local function getAnonymizedUserId(): string
	local localStorageStore = LocalStorageStore.get()
	local storage = localStorageStore.getStorage()

	if storage.telemetryId and storage.telemetryId ~= "" then
		return storage.telemetryId
	end

	local telemetryId = HttpService:GenerateGUID(false)
	localStorageStore.setStorage(function(prev)
		local nextStorage = table.clone(prev)
		nextStorage.telemetryId = telemetryId
		return nextStorage
	end)

	return telemetryId
end

return getAnonymizedUserId
