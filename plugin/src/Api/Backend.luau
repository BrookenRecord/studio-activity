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
export type UnexpectedProblem = { type: "unexpected", statusCode: number, body: string? }

export type TelemetryProblem = NetworkProblem | ValidationProblem | UnexpectedProblem

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
}

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

	return table.freeze({
		captureTelemetryAsync = captureTelemetryAsync,
	})
end

export type BackendApi = typeof(new(...))

return table.freeze({
	new = new,
})
