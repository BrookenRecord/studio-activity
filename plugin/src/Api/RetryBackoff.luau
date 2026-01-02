export type BackoffConfig = {
	--- Initial delay in seconds for the first retry
	initialDelaySeconds: number,
	--- Maximum delay in seconds (caps exponential growth)
	maxDelaySeconds: number,
	--- Base multiplier for exponential growth (default: 2)
	multiplier: number?,
	--- Jitter factor (0 to 1, default: 0.1 = 10% jitter)
	jitterFactor: number?,
}

export type RetryState = {
	--- Number of retry attempts made
	attempt: number,
	--- Last calculated delay in seconds
	lastDelay: number,
}

local DEFAULT_MULTIPLIER = 2
local DEFAULT_JITTER_FACTOR = 0.1

local RetryBackoff = {}

--[[
	Creates a new retry state.
]]
function RetryBackoff.createState(): RetryState
	return {
		attempt = 0,
		lastDelay = 0,
	}
end

--[[
	Calculates the base exponential delay without jitter.
	
	@param config Backoff configuration
	@param attempt Current attempt number (1-indexed)
	@return Base delay in seconds
]]
function RetryBackoff.calculateBaseDelay(config: BackoffConfig, attempt: number): number
	local multiplier = config.multiplier or DEFAULT_MULTIPLIER

	-- For attempt 1, use initialDelaySeconds
	-- For attempt 2, use initialDelaySeconds * multiplier
	-- etc.
	local baseDelay = config.initialDelaySeconds * math.pow(multiplier, attempt - 1)

	-- Cap at maximum delay
	return math.min(baseDelay, config.maxDelaySeconds)
end

--[[
	Applies jitter to a delay value.
	
	@param delay Base delay in seconds
	@param jitterFactor Jitter factor (0 to 1)
	@param randomValue Optional random value for testing (0 to 1)
	@return Delay with jitter applied
]]
function RetryBackoff.applyJitter(delay: number, jitterFactor: number, randomValue: number?): number
	local random = if randomValue ~= nil then randomValue else math.random()

	-- Apply jitter: delay * (1 +/- jitterFactor * random)
	-- This gives us a range of [delay * (1 - jitterFactor), delay * (1 + jitterFactor)]
	local jitterRange = delay * jitterFactor
	local jitter = (random * 2 - 1) * jitterRange -- Random value in [-jitterRange, +jitterRange]

	return math.max(0, delay + jitter)
end

--[[
	Calculates the next retry delay with jitter.
	
	@param config Backoff configuration
	@param state Current retry state
	@param randomValue Optional random value for testing (0 to 1)
	@return Delay in seconds for the next retry
]]
function RetryBackoff.calculateDelay(config: BackoffConfig, state: RetryState, randomValue: number?): number
	local jitterFactor = config.jitterFactor or DEFAULT_JITTER_FACTOR
	local baseDelay = RetryBackoff.calculateBaseDelay(config, state.attempt)

	return RetryBackoff.applyJitter(baseDelay, jitterFactor, randomValue)
end

--[[
	Advances the retry state to the next attempt and calculates delay.
	
	@param config Backoff configuration
	@param state Current retry state (will be mutated)
	@param serverRetryAfter Optional server-provided Retry-After value in seconds
	@param randomValue Optional random value for testing (0 to 1)
	@return Delay in seconds for this retry attempt
]]
function RetryBackoff.nextAttempt(
	config: BackoffConfig,
	state: RetryState,
	serverRetryAfter: number?,
	randomValue: number?
): number
	state.attempt += 1

	local calculatedDelay = RetryBackoff.calculateDelay(config, state, randomValue)

	-- If server provided Retry-After, use the maximum of calculated and server-provided
	local delay = if serverRetryAfter ~= nil and serverRetryAfter > 0
		then math.max(calculatedDelay, serverRetryAfter)
		else calculatedDelay

	state.lastDelay = delay

	return delay
end

--[[
	Resets the retry state to initial values.
]]
function RetryBackoff.reset(state: RetryState)
	state.attempt = 0
	state.lastDelay = 0
end

--[[
	Creates a default backoff configuration suitable for API requests.
]]
function RetryBackoff.defaultConfig(): BackoffConfig
	return {
		initialDelaySeconds = 1,
		maxDelaySeconds = 30,
		multiplier = 2,
		jitterFactor = 0.1,
	}
end

--[[
	Creates a more aggressive backoff configuration for rate-limited requests.
	Uses longer delays since rate limits typically have longer windows.
]]
function RetryBackoff.rateLimitConfig(): BackoffConfig
	return {
		initialDelaySeconds = 5,
		maxDelaySeconds = 60,
		multiplier = 2,
		jitterFactor = 0.2,
	}
end

return RetryBackoff
