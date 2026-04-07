local Plugin = script:FindFirstAncestor("StudioActivity")

local Common = Plugin.Source.Common
local Packages = Plugin.Packages
local JestGlobals = require(Packages.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local jest = JestGlobals.jest
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach

local Debounce = require(Common.Debounce)

describe("Debounce.trailing", function()
	beforeEach(function()
		jest.useFakeTimers()
	end)

	afterEach(function()
		jest.useRealTimers()
	end)

	it("should fire after the delay expires", function()
		local calls = {}
		local debounced = Debounce.trailing(2, function(value)
			table.insert(calls, value)
		end)

		debounced.call("a")
		expect(#calls).toBe(0)

		jest.advanceTimersByTime(2000)
		expect(#calls).toBe(1)
		expect(calls[1]).toBe("a")
	end)

	it("should collapse rapid calls to only the last", function()
		local calls = {}
		local debounced = Debounce.trailing(1, function(value)
			table.insert(calls, value)
		end)

		debounced.call("a")
		debounced.call("b")
		debounced.call("c")

		jest.advanceTimersByTime(1000)
		expect(#calls).toBe(1)
		expect(calls[1]).toBe("c")
	end)

	it("should reset the timer on each call", function()
		local calls = {}
		local debounced = Debounce.trailing(1, function(value)
			table.insert(calls, value)
		end)

		debounced.call("a")
		jest.advanceTimersByTime(500)
		expect(#calls).toBe(0)

		debounced.call("b")
		jest.advanceTimersByTime(500)
		expect(#calls).toBe(0)

		jest.advanceTimersByTime(500)
		expect(#calls).toBe(1)
		expect(calls[1]).toBe("b")
	end)

	it("should not fire after cancel", function()
		local calls = {}
		local debounced = Debounce.trailing(1, function(value)
			table.insert(calls, value)
		end)

		debounced.call("a")
		debounced.cancel()

		jest.advanceTimersByTime(2000)
		expect(#calls).toBe(0)
	end)

	it("should fire immediately on flush", function()
		local calls = {}
		local debounced = Debounce.trailing(10, function(value)
			table.insert(calls, value)
		end)

		debounced.call("a")
		debounced.flush()

		expect(#calls).toBe(1)
		expect(calls[1]).toBe("a")
	end)

	it("should not fire again after flush when timer expires", function()
		local calls = {}
		local debounced = Debounce.trailing(1, function(value)
			table.insert(calls, value)
		end)

		debounced.call("a")
		debounced.flush()
		jest.advanceTimersByTime(2000)

		expect(#calls).toBe(1)
	end)

	it("should do nothing when flush is called with no pending call", function()
		local calls = {}
		local debounced = Debounce.trailing(1, function(value)
			table.insert(calls, value)
		end)

		debounced.flush()
		expect(#calls).toBe(0)
	end)

	it("should pass multiple arguments", function()
		local captured = {}
		local debounced = Debounce.trailing(1, function(a, b, c)
			captured = { a, b, c }
		end)

		debounced.call(1, "two", true)
		jest.advanceTimersByTime(1000)

		expect(captured[1]).toBe(1)
		expect(captured[2]).toBe("two")
		expect(captured[3]).toBe(true)
	end)

	it("should work with zero-arg functions", function()
		local callCount = 0
		local debounced = Debounce.trailing(1, function()
			callCount += 1
		end)

		debounced.call()
		debounced.call()
		jest.advanceTimersByTime(1000)

		expect(callCount).toBe(1)
	end)

	it("should allow new calls after the timer fires", function()
		local calls = {}
		local debounced = Debounce.trailing(1, function(value)
			table.insert(calls, value)
		end)

		debounced.call("first")
		jest.advanceTimersByTime(1000)

		debounced.call("second")
		jest.advanceTimersByTime(1000)

		expect(#calls).toBe(2)
		expect(calls[1]).toBe("first")
		expect(calls[2]).toBe("second")
	end)
end)
