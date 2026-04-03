local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local Notification = require(Plugin.Source.Notification.Notification)

local signal = Charm.signal
local computed = Charm.computed

export type NotificationType = Notification.NotificationType

type QueueEntry = {
	id: number,
	type: NotificationType,
	text: string,
}

export type NotificationStore = {
	getActive: () -> QueueEntry?,
	push: (type: NotificationType, text: string) -> (),
	pop: () -> (),
}

local function createNotificationStore(): NotificationStore
	local getQueue, setQueue = signal<<{ QueueEntry }>>({})
	local nextId = 0

	local getActive = computed(function(): QueueEntry?
		local queue = getQueue()
		return queue[1]
	end)

	local function push(type: NotificationType, text: string)
		nextId += 1
		local id = nextId

		setQueue(function(prev)
			local new = table.clone(prev)
			table.insert(new, {
				id = id,
				type = type,
				text = text,
			})
			return new
		end)
	end

	local function pop()
		setQueue(function(prev)
			if #prev == 0 then
				return prev
			end

			local new = {}
			for i = 2, #prev do
				table.insert(new, prev[i])
			end
			return new
		end)
	end

	return {
		getActive = getActive :: any,
		push = push,
		pop = pop,
	}
end

return createNotificationStore
