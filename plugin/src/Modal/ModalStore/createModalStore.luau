local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local signal = Charm.signal
local computed = Charm.computed

export type ModalId = "addAccount" | "welcome" | "confirmation" | "settings" | "customProfile"

export type ModalStackEntry = {
	id: ModalId,
	priority: number,
	props: { [string]: any }?,
}

export type OpenOptions = {
	priority: number?,
	props: { [string]: any }?,
}

type QueueEntry = ModalStackEntry & {
	-- Multiple callers can `openAsync` the same modal id (e.g. a discard prompt
	-- racing with a delete prompt). We keep them all in a single queue entry --
	-- the first caller's props win, and every waiter resumes with the same
	-- result when the modal closes.
	waitingThreads: { thread }?,
}

export type ModalStore = {
	getModalStack: () -> { ModalStackEntry },
	getActiveModal: () -> ModalId?,
	getActiveProps: () -> { [string]: any }?,

	open: (id: ModalId, options: OpenOptions?) -> (),
	openAsync: (id: ModalId, options: OpenOptions?) -> any,
	close: (id: ModalId?, result: any?) -> (),
}

local function createModalStore(): ModalStore
	local getQueue, setQueue = signal<<{ QueueEntry }>>({})

	local getModalStack = computed(function(): { ModalStackEntry }
		local queue = getQueue()
		local stack = table.create(#queue)
		for index, entry in queue do
			stack[index] = {
				id = entry.id,
				priority = entry.priority,
				props = entry.props,
			}
		end
		return stack
	end)

	local getActiveModal = computed(function(): ModalId?
		local queue = getQueue()
		local first = queue[1]
		return if first then first.id else nil
	end)

	local getActiveProps = computed(function(): { [string]: any }?
		local queue = getQueue()
		local first = queue[1]
		return if first then first.props else nil
	end)

	-- Find the insertion index that maintains priority-descending, FIFO order.
	-- Entries with higher priority come first; within the same priority,
	-- new entries go after existing ones (FIFO).
	local function findInsertIndex(queue: { QueueEntry }, priority: number): number
		for i, entry in queue do
			if entry.priority < priority then
				return i
			end
		end
		return #queue + 1
	end

	local function open(id: ModalId, options: OpenOptions?)
		setQueue(function(prev)
			-- No-op if already queued
			for _, entry in prev do
				if entry.id == id then
					return prev
				end
			end

			local priority = if options then (options.priority or 0) else 0
			local props = if options then options.props else nil

			local new = table.clone(prev)
			local index = findInsertIndex(new, priority)
			table.insert(new, index, {
				id = id,
				priority = priority,
				props = props,
			})
			return new
		end)
	end

	local function openAsync(id: ModalId, options: OpenOptions?): any
		local callingThread = coroutine.running()

		setQueue(function(prev)
			-- If the modal is already queued, attach our thread to its waiter
			-- list so we resume with the same result when it closes. The first
			-- caller's props/priority continue to drive the rendered modal.
			for index, entry in prev do
				if entry.id == id then
					local waiters = if entry.waitingThreads then table.clone(entry.waitingThreads) else {}
					table.insert(waiters, callingThread)

					local new = table.clone(prev)
					new[index] = {
						id = entry.id,
						priority = entry.priority,
						props = entry.props,
						waitingThreads = waiters,
					}
					return new
				end
			end

			local priority = if options then (options.priority or 0) else 0
			local props = if options then options.props else nil

			local new = table.clone(prev)
			local index = findInsertIndex(new, priority)
			table.insert(new, index, {
				id = id,
				priority = priority,
				props = props,
				waitingThreads = { callingThread },
			})
			return new
		end)

		-- Yield until close() resumes us with the result
		return coroutine.yield()
	end

	local function close(id: ModalId?, result: any?)
		local threadsToResume: { thread } = {}

		setQueue(function(prev)
			local targetId = id
			if targetId == nil and prev[1] then
				targetId = prev[1].id
			end

			if targetId == nil then
				return prev
			end

			local new = {}
			for _, entry in prev do
				if entry.id == targetId then
					if entry.waitingThreads then
						for _, thread in entry.waitingThreads do
							table.insert(threadsToResume, thread)
						end
					end
				else
					table.insert(new, entry)
				end
			end

			return new
		end)

		for _, thread in threadsToResume do
			task.spawn(thread, result)
		end
	end

	return {
		getModalStack = getModalStack,
		getActiveModal = getActiveModal :: any,
		getActiveProps = getActiveProps,

		open = open,
		openAsync = openAsync,
		close = close,
	}
end

return createModalStore
