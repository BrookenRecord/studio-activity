--[[
	BackendApi

	Typed wrapper around the Studio Activity backend API.
	All functions that yield are suffixed with `Async`.
	All functions return a Result<V, E> — never throw.

	Follows the same factory + Result pattern as DiscordApi.

	Usage:

		local api = BackendApi.new({
			host = "studio-activity.brooke.sh",
			secure = true,
		})

		local result = api.captureTelemetryAsync(request)
		if not result.ok then
			warn(result.error.type)
		end
]]

local HttpService = game:GetService("HttpService")

local Result = require(script.Parent.Result)
local api = require(script.Parent.Protos.api.v1.api)

-- ────────────────────────────────────────────────────────────
-- Problem types
-- ────────────────────────────────────────────────────────────

export type NetworkProblem = { type: "network", message: string }
export type ValidationProblem = { type: "validation", message: string? }
export type RateLimitedProblem = { type: "rate_limited", retryAfter: number }
export type UnexpectedProblem = { type: "unexpected", statusCode: number, body: string? }

export type TelemetryProblem = NetworkProblem | ValidationProblem | UnexpectedProblem
export type BrowserFlowProblem = NetworkProblem | ValidationProblem | RateLimitedProblem | UnexpectedProblem
export type LatestVersionProblem = NetworkProblem | UnexpectedProblem

-- ────────────────────────────────────────────────────────────
-- Config
-- ────────────────────────────────────────────────────────────

export type Config = {
	host: string,
	secure: boolean,
}

-- ────────────────────────────────────────────────────────────
-- Internal HTTP helpers
-- ────────────────────────────────────────────────────────────

type RawResponse = {
	ok: boolean,
	body: any,
	statusCode: number,
	headers: { [string]: string },
}

local function retryAfter(response: RawResponse): number
	local value = response.headers["Retry-After"] or response.headers["retry-after"]
	if value then
		local seconds = tonumber(value)
		if seconds and seconds > 0 then
			return seconds
		end
	end

	return 5
end

local function postJsonAsync(url: string, jsonBody: string): Result.Result<RawResponse, NetworkProblem>
	local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "POST" :: "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Compress = Enum.HttpCompression.None,
		Body = jsonBody,
	})

	if not requestOk then
		return Result.err({ type = "network" :: "network", message = tostring(result) })
	end

	local body = nil
	if result.Body and #result.Body > 0 then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result.Body)
		body = if decodeOk then decoded else result.Body
	end

	return Result.ok({
		ok = result.Success,
		body = body,
		statusCode = result.StatusCode,
		headers = result.Headers or {},
	})
end

local function getJsonAsync(url: string): Result.Result<RawResponse, NetworkProblem>
	local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "GET" :: "GET",
		Headers = {
			["Accept"] = "application/json",
		},
		Compress = Enum.HttpCompression.None,
	})

	if not requestOk then
		return Result.err({ type = "network" :: "network", message = tostring(result) })
	end

	local body = nil
	if result.Body and #result.Body > 0 then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result.Body)
		body = if decodeOk then decoded else result.Body
	end

	return Result.ok({
		ok = result.Success,
		body = body,
		statusCode = result.StatusCode,
		headers = result.Headers or {},
	})
end

-- ────────────────────────────────────────────────────────────
-- Module
-- ────────────────────────────────────────────────────────────

local function new(config: Config)
	local protocol = if config.secure then "https" else "http"
	local baseUrl = `{protocol}://{config.host}`

	--[[
		Send a telemetry event to the backend.

		POST /v1/telemetry

		The backend validates the event, applies rate limiting, and
		forwards it to PostHog. Returns 204 on success (or silent drop).
	]]
	local function captureTelemetryAsync(request: api.TelemetryRequest): Result.Result<nil, TelemetryProblem>
		local encoded = request:jsonEncode()
		local jsonBody = HttpService:JSONEncode(encoded)

		local res = postJsonAsync(`{baseUrl}/v1/telemetry`, jsonBody)
		if not res.ok then
			return Result.err(res.error)
		end

		if res.value.statusCode == 400 then
			local message: string? = nil
			if type(res.value.body) == "table" then
				message = res.value.body.detail
			end
			return Result.err({
				type = "validation" :: "validation",
				message = message,
			})
		end

		if res.value.ok then
			return Result.ok(nil)
		end

		return Result.err({
			type = "unexpected" :: "unexpected",
			statusCode = res.value.statusCode,
			body = if type(res.value.body) == "string" then res.value.body else nil,
		})
	end

	--[[
		Start a browser-based OAuth2 (PKCE) account-link session.

		POST /v1/oauth/browser/start

		The plugin generates the verifier+challenge locally; only the
		challenge is ever sent to the backend. The backend creates a KV
		entry, mints a session token, and returns a short URL the user
		can paste into their browser.
	]]
	local function startBrowserFlowAsync(
		codeChallenge: string
	): Result.Result<api.BrowserFlowStartResponse, BrowserFlowProblem>
		local request = api.BrowserFlowStartRequest.new({
			codeChallenge = codeChallenge,
		})
		local jsonBody = HttpService:JSONEncode(request:jsonEncode())

		local res = postJsonAsync(`{baseUrl}/v1/oauth/browser/start`, jsonBody)
		if not res.ok then
			return Result.err(res.error)
		end

		if res.value.statusCode == 400 then
			local message: string? = nil
			if type(res.value.body) == "table" then
				message = res.value.body.detail
			end
			return Result.err({
				type = "validation" :: "validation",
				message = message,
			})
		end

		if res.value.statusCode == 429 then
			return Result.err({
				type = "rate_limited" :: "rate_limited",
				retryAfter = retryAfter(res.value),
			})
		end

		if res.value.ok and type(res.value.body) == "table" then
			return Result.ok(api.BrowserFlowStartResponse.jsonDecode(res.value.body))
		end

		return Result.err({
			type = "unexpected" :: "unexpected",
			statusCode = res.value.statusCode,
			body = if type(res.value.body) == "string" then res.value.body else nil,
		})
	end

	--[[
		Poll a browser-flow session for completion.

		POST /v1/oauth/browser/poll

		Returns the current status. When status == COMPLETE, the
		response carries the authorization code (single use — the
		backend deletes the KV entry as soon as it hands it over).
	]]
	local function pollBrowserFlowAsync(
		sessionToken: string
	): Result.Result<api.BrowserFlowPollResponse, BrowserFlowProblem>
		local request = api.BrowserFlowPollRequest.new({
			sessionToken = sessionToken,
		})
		local jsonBody = HttpService:JSONEncode(request:jsonEncode())

		local res = postJsonAsync(`{baseUrl}/v1/oauth/browser/poll`, jsonBody)
		if not res.ok then
			return Result.err(res.error)
		end

		if res.value.statusCode == 400 then
			local message: string? = nil
			if type(res.value.body) == "table" then
				message = res.value.body.detail
			end
			return Result.err({
				type = "validation" :: "validation",
				message = message,
			})
		end

		if res.value.statusCode == 429 then
			return Result.err({
				type = "rate_limited" :: "rate_limited",
				retryAfter = retryAfter(res.value),
			})
		end

		if res.value.ok and type(res.value.body) == "table" then
			return Result.ok(api.BrowserFlowPollResponse.jsonDecode(res.value.body))
		end

		return Result.err({
			type = "unexpected" :: "unexpected",
			statusCode = res.value.statusCode,
			body = if type(res.value.body) == "string" then res.value.body else nil,
		})
	end

	--[[
		Fetch the latest published plugin release.

		GET /v1/version/latest

		The backend caches GitHub's response in KV (~5 min) so plugins
		can poll freely. Used by the footer "Update Available" badge.
	]]
	local function getLatestVersionAsync(): Result.Result<api.LatestVersionResponse, LatestVersionProblem>
		local res = getJsonAsync(`{baseUrl}/v1/version/latest`)
		if not res.ok then
			return Result.err(res.error)
		end

		if res.value.ok and type(res.value.body) == "table" then
			return Result.ok(api.LatestVersionResponse.jsonDecode(res.value.body))
		end

		return Result.err({
			type = "unexpected" :: "unexpected",
			statusCode = res.value.statusCode,
			body = if type(res.value.body) == "string" then res.value.body else nil,
		})
	end

	return table.freeze({
		captureTelemetryAsync = captureTelemetryAsync,
		startBrowserFlowAsync = startBrowserFlowAsync,
		pollBrowserFlowAsync = pollBrowserFlowAsync,
		getLatestVersionAsync = getLatestVersionAsync,
	})
end

export type BackendApi = typeof(new(...))

return table.freeze({
	new = new,
})
