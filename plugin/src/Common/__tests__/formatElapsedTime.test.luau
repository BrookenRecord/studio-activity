local Plugin = script:FindFirstAncestor("StudioActivity")

local Common = Plugin.Source.Common
local Packages = Plugin.Packages
local JestGlobals = require(Packages.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local formatElapsedTime = require(Common.formatElapsedTime)

describe("formatElapsedTime", function()
	describe("seconds only (under 1 minute)", function()
		it("should format 0 seconds as 0:00", function()
			expect(formatElapsedTime(0)).toBe("0:00")
		end)

		it("should zero-pad single digit seconds", function()
			expect(formatElapsedTime(3)).toBe("0:03")
			expect(formatElapsedTime(9)).toBe("0:09")
		end)

		it("should format double digit seconds", function()
			expect(formatElapsedTime(10)).toBe("0:10")
			expect(formatElapsedTime(59)).toBe("0:59")
		end)
	end)

	describe("minutes and seconds (under 1 hour)", function()
		it("should format 1 minute exactly", function()
			expect(formatElapsedTime(60)).toBe("1:00")
		end)

		it("should format minutes with zero-padded seconds", function()
			expect(formatElapsedTime(63)).toBe("1:03")
			expect(formatElapsedTime(125)).toBe("2:05")
		end)

		it("should format larger minute values", function()
			expect(formatElapsedTime(600)).toBe("10:00")
			expect(formatElapsedTime(3599)).toBe("59:59")
		end)
	end)

	describe("hours, minutes, and seconds (1 hour or more)", function()
		it("should format 1 hour exactly", function()
			expect(formatElapsedTime(3600)).toBe("1:00:00")
		end)

		it("should zero-pad minutes and seconds", function()
			expect(formatElapsedTime(3603)).toBe("1:00:03")
			expect(formatElapsedTime(3663)).toBe("1:01:03")
		end)

		it("should format multiple hours", function()
			expect(formatElapsedTime(7200)).toBe("2:00:00")
			expect(formatElapsedTime(36000)).toBe("10:00:00")
		end)

		it("should handle complex time values", function()
			-- 2 hours, 30 minutes, 45 seconds = 9045 seconds
			expect(formatElapsedTime(9045)).toBe("2:30:45")
			-- 12 hours, 5 minutes, 3 seconds = 43503 seconds
			expect(formatElapsedTime(43503)).toBe("12:05:03")
		end)
	end)
end)
