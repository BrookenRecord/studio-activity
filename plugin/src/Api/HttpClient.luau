local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Api = Plugin.Source.Api
local Logger = require(Plugin.Source.Logger)
local Result = require(Api.Result)
local RetryBackoff = require(Api.RetryBackoff)

-- Types
export type HttpMethod = "GET" | "POST" | "PUT" | "DELETE" | "PATCH"

export type HttpHeaders = { [string]: string }

export type HttpRequest = {
	url: string,
	method: HttpMethod,
	headers: HttpHeaders?,
	body: string?,
}

export type HttpResponse = {
	statusCode: number,
	headers: HttpHeaders,
	body: string,
}

export type HttpErrorType = "NetworkError" | "Timeout" | "HttpError" | "ParseError" | "RateLimited"

export type HttpError = {
	-- The type of error that occurred
	type: HttpErrorType,
	-- HTTP status code (only for HttpError and RateLimited)
	statusCode: number?,
	-- Error message
	message: string,
	-- Response body (only for HttpError and RateLimited)
	responseBody: string?,
	-- Retry-After header value in seconds (only for RateLimited)
	retryAfter: number?,
}

export type HttpClientConfig = {
	-- Base URL for all requests
	baseUrl: string,
	-- Default headers to include in all requests
	defaultHeaders: HttpHeaders?,
	-- Maximum number of retry attempts (default: 3)
	maxRetries: number?,
	-- Backoff configuration for retries
	backoffConfig: RetryBackoff.BackoffConfig?,
	-- Whether to retry on rate limit (429) responses (default: true)
	retryOnRateLimit: boolean?,
	-- Whether to retry on server errors (5xx) (default: true)
	retryOnServerError: boolean?,
}

-- Internal type with private fields
type HttpClientInternal = {
	_baseUrl: string,
	_defaultHeaders: HttpHeaders,
	_maxRetries: number,
	_backoffConfig: RetryBackoff.BackoffConfig,
	_retryOnRateLimit: boolean,
	_retryOnServerError: boolean,
}

-- Public type (exported)
export type HttpClient = {
	Request: (self: HttpClient, request: HttpRequest) -> Result.Result<HttpResponse, HttpError>,
	Get: (self: HttpClient, path: string, headers: HttpHeaders?) -> Result.Result<HttpResponse, HttpError>,
	Post: (
		self: HttpClient,
		path: string,
		body: string?,
		headers: HttpHeaders?
	) -> Result.Result<HttpResponse, HttpError>,
}

-- Constants
local DEFAULT_MAX_RETRIES = 3
local STATUS_CODE_RATE_LIMITED = 429

-- Status codes that indicate transient errors worth retrying
local RETRYABLE_STATUS_CODES: { [number]: boolean } = {
	[408] = true, -- Request Timeout
	[429] = true, -- Too Many Requests (Rate Limited)
	[500] = true, -- Internal Server Error
	[502] = true, -- Bad Gateway
	[503] = true, -- Service Unavailable
	[504] = true, -- Gateway Timeout
}

-- Combined type for internal use (includes both public methods and private fields)
type HttpClientImpl = HttpClient & HttpClientInternal

local HttpClient = {}
HttpClient.__index = HttpClient

--[[
	Creates a new HTTP client instance.
]]
function HttpClient.new(config: HttpClientConfig): HttpClient
	Logger:Debug("Creating new HttpClient", { baseUrl = config.baseUrl })

	local self: HttpClientInternal = {
		_baseUrl = config.baseUrl,
		_defaultHeaders = config.defaultHeaders or {},
		_maxRetries = config.maxRetries or DEFAULT_MAX_RETRIES,
		_backoffConfig = config.backoffConfig or RetryBackoff.defaultConfig(),
		_retryOnRateLimit = if config.retryOnRateLimit ~= nil then config.retryOnRateLimit else true,
		_retryOnServerError = if config.retryOnServerError ~= nil then config.retryOnServerError else true,
	}

	return setmetatable(self :: any, HttpClient) :: HttpClient
end

--[[
	Parses the Retry-After header value.
	Returns the retry delay in seconds, or nil if not present/invalid.
]]
local function parseRetryAfter(headers: HttpHeaders): number?
	-- Try different header casing
	local retryAfter = headers["Retry-After"] or headers["retry-after"]
	if not retryAfter then
		return nil
	end

	-- Try to parse as number (seconds)
	local seconds = tonumber(retryAfter)
	if seconds then
		return seconds
	end

	-- Could also be an HTTP date, but we'll skip that complexity for now
	return nil
end

--[[
	Determines if a status code is retryable based on configuration.
]]
local function isRetryable(self: HttpClientImpl, statusCode: number): boolean
	if statusCode == STATUS_CODE_RATE_LIMITED then
		return self._retryOnRateLimit
	end

	if statusCode >= 500 and statusCode < 600 then
		return self._retryOnServerError
	end

	return RETRYABLE_STATUS_CODES[statusCode] == true
end

--[[
	Makes a single HTTP request using HttpService.
]]
local function makeRequest(request: HttpRequest): (boolean, HttpResponse?, string?)
	local options = {
		Url = request.url,
		Method = request.method,
		Headers = request.headers or {},
		Body = request.body,
	}

	local success, response = pcall(function()
		return HttpService:RequestAsync(options)
	end)

	if not success then
		return false, nil, tostring(response)
	end

	return true,
		{
			statusCode = response.StatusCode,
			headers = response.Headers or {},
			body = response.Body or "",
		},
		nil
end

--[[
	Makes an HTTP request with automatic retry and backoff.
]]
function HttpClient.Request(self: HttpClient, request: HttpRequest): Result.Result<HttpResponse, HttpError>
	local impl = self :: HttpClientImpl

	-- Build full URL
	local fullUrl = if string.sub(request.url, 1, 4) == "http" then request.url else impl._baseUrl .. request.url

	Logger:Debug(`HTTP {request.method} {fullUrl}`)

	-- Merge headers using table.clone
	local headers: HttpHeaders = table.clone(impl._defaultHeaders)
	if request.headers then
		for key, value in request.headers do
			headers[key] = value
		end
	end

	local fullRequest: HttpRequest = {
		url = fullUrl,
		method = request.method,
		headers = headers,
		body = request.body,
	}

	local retryState = RetryBackoff.createState()
	local lastError: HttpError? = nil

	for attempt = 1, impl._maxRetries + 1 do
		if attempt > 1 then
			Logger:Debug(`Retry attempt {attempt - 1}/{impl._maxRetries} for {request.method} {fullUrl}`)
		end

		-- Make the request
		local success, response, errorMessage = makeRequest(fullRequest)

		if not success or response == nil then
			-- Network-level error (DNS failure, timeout, etc.)
			Logger:Warn(`Network error for {request.method} {fullUrl}: {errorMessage or "Unknown error"}`)

			local err: HttpError = {
				type = "NetworkError" :: HttpErrorType,
				message = errorMessage or "Unknown network error",
			}
			lastError = err

			-- Retry network errors
			if attempt <= impl._maxRetries then
				local delay = RetryBackoff.nextAttempt(impl._backoffConfig, retryState, nil)
				Logger:Debug(`Waiting {delay}s before retry`)
				task.wait(delay)
				continue
			end

			Logger:Error(`Max retries exceeded for {request.method} {fullUrl}`)
			return Result.err(err)
		end

		-- Got a response - check if successful
		local statusCode = response.statusCode

		if statusCode >= 200 and statusCode < 300 then
			-- Success!
			Logger:Debug(`HTTP {request.method} {fullUrl} -> {statusCode}`)
			return Result.ok(response)
		end

		-- Check if rate limited
		if statusCode == STATUS_CODE_RATE_LIMITED then
			local retryAfter = parseRetryAfter(response.headers)
			Logger:Warn(`Rate limited on {request.method} {fullUrl}, retry-after: {retryAfter or "not specified"}`)

			local err: HttpError = {
				type = "RateLimited" :: HttpErrorType,
				statusCode = statusCode,
				message = "Rate limited",
				responseBody = response.body,
				retryAfter = retryAfter,
			}
			lastError = err

			-- Retry rate limits if configured
			if impl._retryOnRateLimit and attempt <= impl._maxRetries then
				local delay = RetryBackoff.nextAttempt(impl._backoffConfig, retryState, retryAfter)
				Logger:Debug(`Waiting {delay}s before retry`)
				task.wait(delay)
				continue
			end

			return Result.err(err)
		end

		-- Check if it's a retryable error
		if isRetryable(impl, statusCode) then
			Logger:Warn(`Retryable HTTP error {statusCode} for {request.method} {fullUrl}`)

			local err: HttpError = {
				type = "HttpError" :: HttpErrorType,
				statusCode = statusCode,
				message = `HTTP error: {statusCode}`,
				responseBody = response.body,
			}
			lastError = err

			if attempt <= impl._maxRetries then
				local delay = RetryBackoff.nextAttempt(impl._backoffConfig, retryState, nil)
				Logger:Debug(`Waiting {delay}s before retry`)
				task.wait(delay)
				continue
			end

			Logger:Error(`Max retries exceeded for {request.method} {fullUrl}`)
			return Result.err(err)
		end

		-- Non-retryable HTTP error
		Logger:Warn(`HTTP error {statusCode} for {request.method} {fullUrl}`)
		local nonRetryableErr: HttpError = {
			type = "HttpError" :: HttpErrorType,
			statusCode = statusCode,
			message = `HTTP error: {statusCode}`,
			responseBody = response.body,
		}
		return Result.err(nonRetryableErr)
	end

	-- Should not reach here, but return last error if we do
	Logger:Error(`Unexpected end of retry loop for {request.method} {fullUrl}`)
	local finalErr: HttpError = lastError
		or {
			type = "NetworkError" :: HttpErrorType,
			message = "Max retries exceeded",
		}
	return Result.err(finalErr)
end

--[[
	Makes a GET request.
]]
function HttpClient.Get(self: HttpClient, path: string, headers: HttpHeaders?): Result.Result<HttpResponse, HttpError>
	return self:Request({
		url = path,
		method = "GET",
		headers = headers,
	})
end

--[[
	Makes a POST request.
]]
function HttpClient.Post(
	self: HttpClient,
	path: string,
	body: string?,
	headers: HttpHeaders?
): Result.Result<HttpResponse, HttpError>
	return self:Request({
		url = path,
		method = "POST",
		headers = headers,
		body = body,
	})
end

return HttpClient
