--[[
	Trailing-edge debounce: when called repeatedly within a window, only the
	last invocation fires after the window expires.

	Usage:

		local debounced = Debounce.trailing(2, function(value)
			print("final value:", value)
		end)

		debounced.call("a")  -- schedules fire in 2s
		debounced.call("b")  -- resets timer, "a" is dropped
		-- 2s later: prints "final value: b"

		debounced.cancel()   -- cancels any pending call
		debounced.flush()    -- fires immediately if pending, then resets
]]

export type DebouncedFn = {
	call: (...any) -> (),
	cancel: () -> (),
	flush: () -> (),
}

local Debounce = {}

function Debounce.trailing(delaySeconds: number, fn: (...any) -> ()): DebouncedFn
	local pendingThread: thread? = nil
	local pendingArgs: { any }? = nil

	local function cancel()
		if pendingThread then
			pcall(task.cancel, pendingThread)
			pendingThread = nil
		end
		pendingArgs = nil
	end

	local function flush()
		if pendingArgs then
			local args = pendingArgs
			cancel()
			fn(table.unpack(args))
		end
	end

	local function call(...)
		pendingArgs = { ... }

		if pendingThread then
			pcall(task.cancel, pendingThread)
		end

		pendingThread = task.delay(delaySeconds, function()
			pendingThread = nil
			local args = pendingArgs
			pendingArgs = nil
			if args then
				fn(table.unpack(args))
			end
		end)
	end

	return table.freeze({
		call = call,
		cancel = cancel,
		flush = flush,
	})
end

return table.freeze(Debounce)
