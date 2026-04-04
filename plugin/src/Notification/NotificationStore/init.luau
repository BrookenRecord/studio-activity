local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local createNotificationStore = require(script.createNotificationStore)
export type NotificationType = createNotificationStore.NotificationType

return {
	get = Charm.computed(createNotificationStore),
}
