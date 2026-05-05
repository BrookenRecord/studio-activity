local Plugin = script:FindFirstAncestor("StudioActivity")

local Api = Plugin.Source.Api
local Packages = Plugin.Packages
local JestGlobals = require(Packages.Dev.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local beforeEach = JestGlobals.beforeEach

local RetryBackoff = require(Api.RetryBackoff)

describe("RetryBackoff", function()
	describe("createState", function()
		it("should create initial state with zero values", function()
			local state = RetryBackoff.createState()

			expect(state.attempt).toBe(0)
			expect(state.lastDelay).toBe(0)
		end)
	end)

	describe("calculateBaseDelay", function()
		local config: RetryBackoff.BackoffConfig

		beforeEach(function()
			config = {
				initialDelaySeconds = 1,
				maxDelaySeconds = 30,
				multiplier = 2,
			}
		end)

		it("should return initial delay for first attempt", function()
			local delay = RetryBackoff.calculateBaseDelay(config, 1)
			expect(delay).toBe(1)
		end)

		it("should double delay for each subsequent attempt", function()
			expect(RetryBackoff.calculateBaseDelay(config, 1)).toBe(1)
			expect(RetryBackoff.calculateBaseDelay(config, 2)).toBe(2)
			expect(RetryBackoff.calculateBaseDelay(config, 3)).toBe(4)
			expect(RetryBackoff.calculateBaseDelay(config, 4)).toBe(8)
			expect(RetryBackoff.calculateBaseDelay(config, 5)).toBe(16)
		end)

		it("should cap delay at maxDelaySeconds", function()
			local delay = RetryBackoff.calculateBaseDelay(config, 10)
			expect(delay).toBe(30)
		end)

		it("should work with custom multiplier", function()
			config.multiplier = 3

			expect(RetryBackoff.calculateBaseDelay(config, 1)).toBe(1)
			expect(RetryBackoff.calculateBaseDelay(config, 2)).toBe(3)
			expect(RetryBackoff.calculateBaseDelay(config, 3)).toBe(9)
			expect(RetryBackoff.calculateBaseDelay(config, 4)).toBe(27)
		end)

		it("should use default multiplier of 2 when not specified", function()
			config.multiplier = nil

			expect(RetryBackoff.calculateBaseDelay(config, 1)).toBe(1)
			expect(RetryBackoff.calculateBaseDelay(config, 2)).toBe(2)
			expect(RetryBackoff.calculateBaseDelay(config, 3)).toBe(4)
		end)

		it("should handle different initial delays", function()
			config.initialDelaySeconds = 5

			expect(RetryBackoff.calculateBaseDelay(config, 1)).toBe(5)
			expect(RetryBackoff.calculateBaseDelay(config, 2)).toBe(10)
			expect(RetryBackoff.calculateBaseDelay(config, 3)).toBe(20)
			expect(RetryBackoff.calculateBaseDelay(config, 4)).toBe(30) -- Capped
		end)
	end)

	describe("applyJitter", function()
		it("should return exact delay when random is 0.5 (center)", function()
			-- When random = 0.5, jitter = 0 (centered)
			-- jitter = (0.5 * 2 - 1) * jitterRange = 0 * jitterRange = 0
			local delay = RetryBackoff.applyJitter(10, 0.1, 0.5)
			expect(delay).toBe(10)
		end)

		it("should increase delay when random is high", function()
			-- When random = 1.0, jitter = +jitterRange
			-- jitter = (1.0 * 2 - 1) * (10 * 0.1) = 1 * 1 = 1
			local delay = RetryBackoff.applyJitter(10, 0.1, 1.0)
			expect(delay).toBe(11)
		end)

		it("should decrease delay when random is low", function()
			-- When random = 0.0, jitter = -jitterRange
			-- jitter = (0.0 * 2 - 1) * (10 * 0.1) = -1 * 1 = -1
			local delay = RetryBackoff.applyJitter(10, 0.1, 0.0)
			expect(delay).toBe(9)
		end)

		it("should handle larger jitter factors", function()
			-- With 50% jitter factor
			local delayHigh = RetryBackoff.applyJitter(10, 0.5, 1.0)
			local delayLow = RetryBackoff.applyJitter(10, 0.5, 0.0)

			expect(delayHigh).toBe(15) -- 10 + 5
			expect(delayLow).toBe(5) -- 10 - 5
		end)

		it("should not return negative delays", function()
			-- Even with aggressive jitter, delay should not go negative
			local delay = RetryBackoff.applyJitter(1, 0.9, 0.0)
			expect(delay).toBeGreaterThanOrEqual(0)
		end)

		it("should handle zero delay", function()
			local delay = RetryBackoff.applyJitter(0, 0.1, 0.5)
			expect(delay).toBe(0)
		end)

		it("should handle zero jitter factor", function()
			local delay = RetryBackoff.applyJitter(10, 0, 0.0)
			expect(delay).toBe(10)
		end)
	end)

	describe("calculateDelay", function()
		local config: RetryBackoff.BackoffConfig
		local state: RetryBackoff.RetryState

		beforeEach(function()
			config = {
				initialDelaySeconds = 1,
				maxDelaySeconds = 30,
				multiplier = 2,
				jitterFactor = 0.1,
			}
			state = RetryBackoff.createState()
		end)

		it("should calculate delay with jitter applied", function()
			state.attempt = 1

			-- With random = 0.5, jitter is 0, so delay = 1
			local delay = RetryBackoff.calculateDelay(config, state, 0.5)
			expect(delay).toBe(1)
		end)

		it("should use default jitter factor when not specified", function()
			config.jitterFactor = nil
			state.attempt = 1

			-- Default jitter factor is 0.1
			local delayMin = RetryBackoff.calculateDelay(config, state, 0.0)
			local delayMax = RetryBackoff.calculateDelay(config, state, 1.0)

			expect(delayMin).toBe(0.9) -- 1 - 0.1
			expect(delayMax).toBe(1.1) -- 1 + 0.1
		end)
	end)

	describe("nextAttempt", function()
		local config: RetryBackoff.BackoffConfig
		local state: RetryBackoff.RetryState

		beforeEach(function()
			config = {
				initialDelaySeconds = 1,
				maxDelaySeconds = 30,
				multiplier = 2,
				jitterFactor = 0.1,
			}
			state = RetryBackoff.createState()
		end)

		it("should increment attempt counter", function()
			expect(state.attempt).toBe(0)

			RetryBackoff.nextAttempt(config, state, nil, 0.5)
			expect(state.attempt).toBe(1)

			RetryBackoff.nextAttempt(config, state, nil, 0.5)
			expect(state.attempt).toBe(2)
		end)

		it("should update lastDelay", function()
			local delay = RetryBackoff.nextAttempt(config, state, nil, 0.5)

			expect(state.lastDelay).toBe(delay)
		end)

		it("should return calculated delay without server retry-after", function()
			local delay = RetryBackoff.nextAttempt(config, state, nil, 0.5)

			-- First attempt: 1 second base, no jitter at 0.5
			expect(delay).toBe(1)
		end)

		it("should use server retry-after when larger than calculated", function()
			-- Calculated would be ~1 second, but server says 10
			local delay = RetryBackoff.nextAttempt(config, state, 10, 0.5)

			expect(delay).toBe(10)
		end)

		it("should ignore server retry-after when smaller than calculated", function()
			-- Make state have higher attempt for larger calculated delay
			state.attempt = 4
			-- Next attempt (5) would have base delay = 1 * 2^4 = 16
			local delay = RetryBackoff.nextAttempt(config, state, 5, 0.5)

			-- Calculated ~16, server says 5, should use 16
			expect(delay).toBe(16)
		end)

		it("should ignore negative server retry-after", function()
			local delay = RetryBackoff.nextAttempt(config, state, -5, 0.5)

			expect(delay).toBe(1) -- Just the calculated delay
		end)

		it("should ignore zero server retry-after", function()
			local delay = RetryBackoff.nextAttempt(config, state, 0, 0.5)

			expect(delay).toBe(1) -- Just the calculated delay
		end)

		it("should produce increasing delays for sequential attempts", function()
			local delay1 = RetryBackoff.nextAttempt(config, state, nil, 0.5)
			local delay2 = RetryBackoff.nextAttempt(config, state, nil, 0.5)
			local delay3 = RetryBackoff.nextAttempt(config, state, nil, 0.5)

			expect(delay1).toBe(1)
			expect(delay2).toBe(2)
			expect(delay3).toBe(4)
		end)
	end)

	describe("reset", function()
		it("should reset state to initial values", function()
			local state = RetryBackoff.createState()
			state.attempt = 5
			state.lastDelay = 16

			RetryBackoff.reset(state)

			expect(state.attempt).toBe(0)
			expect(state.lastDelay).toBe(0)
		end)
	end)

	describe("defaultConfig", function()
		it("should return a valid configuration", function()
			local config = RetryBackoff.defaultConfig()

			expect(config.initialDelaySeconds).toBe(1)
			expect(config.maxDelaySeconds).toBe(30)
			expect(config.multiplier).toBe(2)
			expect(config.jitterFactor).toBe(0.1)
		end)

		it("should work with calculateBaseDelay", function()
			local config = RetryBackoff.defaultConfig()

			-- Should not throw
			local delay = RetryBackoff.calculateBaseDelay(config, 1)
			expect(delay).toBe(1)
		end)
	end)

	describe("rateLimitConfig", function()
		it("should return a configuration suitable for rate limits", function()
			local config = RetryBackoff.rateLimitConfig()

			expect(config.initialDelaySeconds).toBe(5)
			expect(config.maxDelaySeconds).toBe(60)
			expect(config.multiplier).toBe(2)
			expect(config.jitterFactor).toBe(0.2)
		end)

		it("should have longer delays than default config", function()
			local defaultConfig = RetryBackoff.defaultConfig()
			local rateLimitConfig = RetryBackoff.rateLimitConfig()

			expect(rateLimitConfig.initialDelaySeconds).toBeGreaterThan(defaultConfig.initialDelaySeconds)
			expect(rateLimitConfig.maxDelaySeconds).toBeGreaterThan(defaultConfig.maxDelaySeconds)
		end)
	end)

	describe("integration: full retry sequence", function()
		it("should produce reasonable delays for a typical retry sequence", function()
			local config = RetryBackoff.defaultConfig()
			local state = RetryBackoff.createState()

			-- Simulate 5 retries with consistent randomness
			local delays = {}
			for _ = 1, 5 do
				table.insert(delays, RetryBackoff.nextAttempt(config, state, nil, 0.5))
			end

			-- Expected: 1, 2, 4, 8, 16 (with no jitter at random=0.5)
			expect(delays[1]).toBe(1)
			expect(delays[2]).toBe(2)
			expect(delays[3]).toBe(4)
			expect(delays[4]).toBe(8)
			expect(delays[5]).toBe(16)
		end)

		it("should cap delays at maximum", function()
			local config = {
				initialDelaySeconds = 1,
				maxDelaySeconds = 10,
				multiplier = 2,
				jitterFactor = 0,
			}
			local state = RetryBackoff.createState()

			-- After enough retries, delay should cap at 10
			for _ = 1, 10 do
				RetryBackoff.nextAttempt(config, state, nil, 0.5)
			end

			expect(state.lastDelay).toBe(10)
		end)

		it("should reset and start over correctly", function()
			local config = RetryBackoff.defaultConfig()
			local state = RetryBackoff.createState()

			-- Do some retries
			RetryBackoff.nextAttempt(config, state, nil, 0.5)
			RetryBackoff.nextAttempt(config, state, nil, 0.5)
			RetryBackoff.nextAttempt(config, state, nil, 0.5)

			expect(state.attempt).toBe(3)

			-- Reset
			RetryBackoff.reset(state)

			-- Start over
			local delay = RetryBackoff.nextAttempt(config, state, nil, 0.5)

			expect(state.attempt).toBe(1)
			expect(delay).toBe(1)
		end)
	end)
end)
