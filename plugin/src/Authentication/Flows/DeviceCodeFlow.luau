--[[
	DeviceCodeFlow

	Implements the Discord device code OAuth2 grant for Studio plugins.
	Exposes reactive charm signals for driving UI updates.

	The flow is fully restartable — calling requestAsync() again cancels
	any in-progress polling and starts fresh with a new device code.

	All external dependencies are injected via the config table for testability.
	In production, pass real HttpService/BuildVars. In tests, pass stubs.

	Usage:

		local flow = DeviceCodeFlow.create({
			httpService = game:GetService("HttpService"),
			clientId = "YOUR_CLIENT_ID",
		})

		-- Start or restart the flow (can be called multiple times)
		flow.requestAsync()

		-- UI reads state via charm signals:
		--   flow.status()       → "idle" | "requesting" | "polling" | "authorized" | "denied" | "expired" | "error"
		--   flow.sessionInfo()  → SessionInfo? (available once status is "polling")
		--   flow.tokenResult()  → TokenResult? (available once status is "authorized")
		--   flow.error()        → string? (available when status is "error")

		-- Cleanup when done
		flow.destroy()
]]

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local AccountStore = require(script.Parent.Parent.AccountStore)

local signal = Charm.signal
local batch = Charm.batch

-- Sane defaults, overridable for testing
local DEFAULT_API_BASE = "https://discord.com/api/v10"
local DEFAULT_SCOPE = "sdk.social_layer_presence"

-- Polling bounds to protect against server misconfig or bugs
local MIN_POLL_INTERVAL = 1
local MAX_POLL_INTERVAL = 30

--[[ Types ]]

export type Status = "idle" | "requesting" | "polling" | "authorized" | "denied" | "expired" | "error"

export type SessionInfo = {
	deviceCode: string,
	userCode: string,
	verificationUrl: string,
	verificationUrlComplete: string,
	expiresIn: number,
	interval: number,
}

export type Config = {
	httpService: HttpService,
	clientId: string,
	scope: string?,
	apiBase: string?,
}

--[[ Internal helpers ]]

local function urlEncode(httpService: HttpService, params: { [string]: string }): string
	local parts = {}
	for key, value in params do
		table.insert(parts, `{httpService:UrlEncode(key)}={httpService:UrlEncode(value)}`)
	end
	return table.concat(parts, "&")
end

-- Wraps HttpService:RequestAsync with pcall, JSON decoding, and a
-- normalized return shape. Never throws — all errors are in the return.
local function postForm(httpService: HttpService, url: string, params: { [string]: string }): (boolean, any, number)
	local body = urlEncode(httpService, params)

	local ok, result = pcall(function()
		return httpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/x-www-form-urlencoded",
			} :: any,
			-- Gzip is not supported by discord
			Compress = Enum.HttpCompression.None,
			Body = body,
		})
	end)

	if not ok then
		return false, tostring(result), 0
	end

	local decoded = nil
	if result.Body and #result.Body > 0 then
		local decodeOk, decodeResult = pcall(httpService.JSONDecode, httpService, result.Body)
		decoded = if decodeOk then decodeResult else result.Body
	end

	return result.Success, decoded, result.StatusCode
end

--[[ Module ]]

local function create(config: Config)
	-- Unpack config with defaults
	local httpService = config.httpService
	local clientId = config.clientId
	local scope = config.scope or DEFAULT_SCOPE
	local apiBase = config.apiBase or DEFAULT_API_BASE

	-- Reactive state
	local status, setStatus = signal("idle" :: Status)
	local sessionInfo, setSessionInfo = signal(nil :: SessionInfo?)
	local errorMessage, setErrorMessage = signal(nil :: string?)

	local accountStore = AccountStore.get()

	-- Active thread tracking for cancellation
	local activeThread: thread? = nil

	-- Cancel whatever's currently running (device code request or poll loop).
	-- Safe to call multiple times or when nothing is running.
	local function cancelActive()
		if activeThread then
			pcall(task.cancel, activeThread)
			activeThread = nil
		end
	end

	-- Reset all signals to a clean state. Used before starting a new flow
	-- and during destroy.
	local function resetState()
		batch(function()
			setStatus("idle")
			setSessionInfo(nil)
			setErrorMessage(nil)
		end)
	end

	-- Build the base params that appear in every token endpoint request.
	local function baseParams(): { [string]: string }
		local params: { [string]: string } = {
			client_id = clientId,
		}
		return params
	end

	-- Request a device code from Discord. On success, transitions to
	-- "polling" and begins the poll loop automatically.
	-- This is the internal async implementation — the public API wraps
	-- it in a managed thread.
	local function flowAsync()
		-- Phase 1: Request device code
		batch(function()
			setStatus("requesting")
			setErrorMessage(nil)
		end)

		local deviceUrl = `{apiBase}/oauth2/device/authorize`
		local deviceParams = baseParams()
		deviceParams.scope = scope

		local ok, body, statusCode = postForm(httpService, deviceUrl, deviceParams)

		if not ok then
			batch(function()
				setStatus("error")
				setErrorMessage(
					if type(body) == "table" and body.message then body.message else `Request failed ({statusCode})`
				)
			end)
			return
		end

		if type(body) ~= "table" or not body.device_code then
			batch(function()
				setStatus("error")
				setErrorMessage("Unexpected response from Discord")
			end)
			return
		end

		local info: SessionInfo = {
			deviceCode = body.device_code,
			userCode = body.user_code,
			verificationUrl = body.verification_uri,
			verificationUrlComplete = body.verification_uri_complete,
			expiresIn = body.expires_in,
			interval = body.interval,
		}

		batch(function()
			setStatus("polling")
			setSessionInfo(info)
		end)

		-- Phase 2: Poll for token
		local tokenUrl = `{apiBase}/oauth2/token`
		local interval = math.clamp(info.interval, MIN_POLL_INTERVAL, MAX_POLL_INTERVAL)
		local deadline = os.clock() + info.expiresIn

		while os.clock() < deadline do
			task.wait(interval)

			local pollParams = baseParams()
			pollParams.grant_type = "urn:ietf:params:oauth:grant-type:device_code"
			pollParams.device_code = info.deviceCode

			local pollOk, pollBody, pollStatus = postForm(httpService, tokenUrl, pollParams)

			-- Token granted
			if pollOk and pollStatus == 200 and type(pollBody) == "table" then
				setStatus("authorized")

				-- Add the authorized user to the account store
				-- TODO: Expose better error handling on this API
				accountStore.addUserAsync({
					accessToken = pollBody.access_token,
					refreshToken = pollBody.refresh_token,
					expiresAt = os.time() + (pollBody.expires_in or 604800),
				})

				return
			end

			-- Expected polling responses (all come as 400s)
			if pollStatus == 400 and type(pollBody) == "table" then
				local pollError = pollBody.error

				if pollError == "authorization_pending" then
					continue
				end

				if pollError == "slow_down" then
					interval = math.min(interval + 1, MAX_POLL_INTERVAL)
					continue
				end

				if pollError == "expired_token" then
					batch(function()
						setStatus("expired")
						setSessionInfo(nil)
					end)
					return
				end

				if pollError == "access_denied" then
					batch(function()
						setStatus("denied")
						setSessionInfo(nil)
					end)
					return
				end
			end

			-- Unexpected error — stop polling, surface to UI
			batch(function()
				setStatus("error")
				setErrorMessage(
					if type(pollBody) == "table" and pollBody.message
						then pollBody.message
						else `Polling failed ({pollStatus})`
				)
			end)
			return
		end

		-- Fell through the loop — code expired by wall clock
		batch(function()
			setStatus("expired")
			setSessionInfo(nil)
		end)
	end

	--[[ Public API ]]

	-- Start or restart the device code flow. Cancels any in-progress
	-- request or poll loop before starting fresh. Safe to call from
	-- any state — "idle", "polling", "error", "expired", etc.
	--
	-- Fires and forgets. UI observes progress via the signals.
	local function requestAsync()
		cancelActive()
		resetState()

		activeThread = task.defer(function()
			flowAsync()
			-- Clear the thread ref when we finish naturally
			activeThread = nil
		end)
	end

	-- Tear down the flow completely. Cancels active work and resets
	-- all signals. The instance should not be reused after this.
	local function destroy()
		cancelActive()
		resetState()
	end

	return table.freeze({
		-- Signals (read-only from outside)
		status = status,
		sessionInfo = sessionInfo,
		error = errorMessage,

		-- Actions
		requestAsync = requestAsync,
		destroy = destroy,
	})
end

export type DeviceCodeFlow = typeof(create(nil :: any))

return table.freeze({
	create = create,
})
