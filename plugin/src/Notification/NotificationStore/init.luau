local createNotificationStore = require(script.createNotificationStore)
export type NotificationType = createNotificationStore.NotificationType

local instance = nil

local function get()
	if not instance then
		instance = createNotificationStore()
	end
	return instance
end

return { get = get }
