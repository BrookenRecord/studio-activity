local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local Notification = require(script.Parent.Notification)
local NotificationStore = require(script.Parent.NotificationStore)

local View = Foundation.View

local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useCallback = React.useCallback

local function NotificationsContainer()
	local notificationStore = NotificationStore.get()
	local active = useSignalState(notificationStore.getActive)

	local onClose = useCallback(function()
		notificationStore.pop()
	end, { notificationStore })

	return e(View, {
		tag = "size-full",
		ZIndex = 10,
	}, {
		ActiveNotification = active and e(Notification, {
			key = active.id,
			type = active.type,
			text = active.text,
			onClose = onClose,
		}),
	})
end

return React.memo(NotificationsContainer)
