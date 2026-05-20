local Plugin = script:FindFirstAncestor("StudioActivity")

local createNotificationStore = require(script.createNotificationStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)
export type NotificationType = createNotificationStore.NotificationType

return {
	get = createSingleton(createNotificationStore),
}
