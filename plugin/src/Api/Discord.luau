--[[
	DiscordApi

	Typed wrapper around every Discord API endpoint this plugin needs.
	All functions that yield are suffixed with `Async`.
	All functions return a Result<V, E> — never throw.

	HttpService is imported from an adjacent module so tests can
	swap it with a stub.

	Usage:

		local api = DiscordApi.new({
			clientId = "YOUR_CLIENT_ID",
		})

		local result = api.requestDeviceCodeAsync()
		if result.ok then
			print(result.value.userCode)
		else
			warn(result.problem.type, result.problem.message)
		end
]]

local HttpService = game:GetService("HttpService")

local Result = require(script.Parent.Result)

-- ────────────────────────────────────────────────────────────
-- Problem types
--
-- Each API function returns a Result whose error side is a
-- union of these. Callers pattern-match on `problem.type`.
-- ────────────────────────────────────────────────────────────

--  Can appear on any endpoint
export type NetworkProblem = { type: "network", message: string }
export type UnexpectedProblem = { type: "unexpected", statusCode: number, body: string? }

-- OAuth2 token endpoint (device code exchange)
export type AuthorizationPendingProblem = { type: "authorization_pending" }
export type SlowDownProblem = { type: "slow_down" }
export type ExpiredTokenProblem = { type: "expired_token" }
export type AccessDeniedProblem = { type: "access_denied" }

-- OAuth2 token endpoint (refresh)
export type InvalidGrantProblem = { type: "invalid_grant" }

-- OAuth2 token endpoint (device code request)
export type InvalidScopeProblem = { type: "invalid_scope", description: string? }

-- Any authenticated endpoint
export type UnauthorizedProblem = { type: "unauthorized" }

-- Headless session create (202 means app isn't cached yet)
export type ApplicationNotCachedProblem = { type: "application_not_cached", retryAfter: number }

-- Any rate-limited endpoint (429). retryAfter is in seconds (float).
export type RateLimitedProblem = { type: "rate_limited", retryAfter: number }

-- Composite problem types per endpoint
export type DeviceCodeProblem = NetworkProblem | InvalidScopeProblem | UnexpectedProblem

export type DeviceCodeExchangeProblem =
	| AuthorizationPendingProblem
	| SlowDownProblem
	| ExpiredTokenProblem
	| AccessDeniedProblem
	| NetworkProblem
	| UnexpectedProblem

export type RefreshProblem = InvalidGrantProblem | NetworkProblem | UnexpectedProblem

export type AuthenticatedProblem = UnauthorizedProblem | RateLimitedProblem | NetworkProblem | UnexpectedProblem

export type HeadlessSessionCreateProblem =
	| UnauthorizedProblem
	| ApplicationNotCachedProblem
	| RateLimitedProblem
	| NetworkProblem
	| UnexpectedProblem

export type AvatarProblem = NetworkProblem | UnexpectedProblem
export type ApplicationAssetsProblem = NetworkProblem | UnexpectedProblem

-- ────────────────────────────────────────────────────────────
-- Value types
-- ────────────────────────────────────────────────────────────

export type DeviceCodeSession = {
	deviceCode: string,
	userCode: string,
	verificationUrl: string,
	verificationUrlComplete: string,
	expiresIn: number,
	interval: number,
}

export type TokenResult = {
	accessToken: string,
	refreshToken: string?,
	expiresAt: number,
	scope: string,
	tokenType: string,
}

export type User = {
	id: string,
	username: string,
	globalName: string?,
	avatar: string?,
}

export type AvatarImage = {
	data: string, -- raw PNG bytes
	contentType: string,
}

export type ApplicationAsset = {
	id: string,
	name: string,
	assetType: number, -- 1 = large, 2 = small
}

export type Activity = {
	type: number,
	name: string,
	application_id: string?,
	platform: string?,
	details: string?,
	details_url: string?,
	state: string?,
	state_url: string?,
	timestamps: { start: string?, ["end"]: string? }?,
	assets: { large_image: string?, large_text: string?, small_image: string?, small_text: string? }?,
	party: { id: string?, size: { number }? }?,
}

export type HeadlessSession = {
	sessionToken: string,
	activities: { Activity },
}

-- ────────────────────────────────────────────────────────────
-- Config
-- ────────────────────────────────────────────────────────────

export type Config = {
	clientId: string,
	scope: string?,
	apiBase: string?,
}

local DEFAULT_API_BASE = "https://discord.com/api/v10"
local DEFAULT_SCOPE = "sdk.social_layer_presence"

-- ────────────────────────────────────────────────────────────
-- Internal HTTP helpers
-- ────────────────────────────────────────────────────────────

local function urlEncode(params: { [string]: string }): string
	local parts = {}
	for key, value in params do
		table.insert(parts, `{HttpService:UrlEncode(key)}={HttpService:UrlEncode(value)}`)
	end
	return table.concat(parts, "&")
end

type RawResponse = {
	ok: boolean,
	body: any,
	statusCode: number,
}

-- POST with application/x-www-form-urlencoded body.
-- Never throws. Returns a normalized response or a NetworkProblem.
local function postFormAsync(url: string, params: { [string]: string }): Result.Result<RawResponse, NetworkProblem>
	local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "POST" :: "POST",
		Headers = {
			["Content-Type"] = "application/x-www-form-urlencoded",
		},
		Compress = Enum.HttpCompression.None,
		Body = urlEncode(params),
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

-- POST with JSON body and Bearer auth.
local function postJsonAuthAsync(
	url: string,
	data: any,
	accessToken: string
): Result.Result<RawResponse, NetworkProblem>
	local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "POST" :: "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = `Bearer {accessToken}`,
		},
		Compress = Enum.HttpCompression.None,
		Body = HttpService:JSONEncode(data),
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

-- GET with Bearer auth.
local function getJsonAuthAsync(url: string, accessToken: string): Result.Result<RawResponse, NetworkProblem>
	local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "GET" :: "GET",
		Headers = {
			["Authorization"] = `Bearer {accessToken}`,
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
	})
end

-- GET without auth (public endpoints).
local function getJsonAsync(url: string): Result.Result<RawResponse, NetworkProblem>
	local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = url,
		Method = "GET" :: "GET",
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
	})
end

-- Helper to extract the OAuth2 error string from a response body,
-- or nil if the body isn't in the expected { error: "...", ... } shape.
local function oauthError(body: any): string?
	if type(body) == "table" then
		return body.error
	end
	return nil
end

-- Helper to build an UnexpectedProblem from a RawResponse.
local function unexpected(res: RawResponse): UnexpectedProblem
	return {
		type = "unexpected",
		statusCode = res.statusCode,
		body = if type(res.body) == "string" then res.body else nil,
	}
end

-- ────────────────────────────────────────────────────────────
-- Module
-- ────────────────────────────────────────────────────────────

local function new(config: Config)
	local clientId = config.clientId
	local scope = config.scope or DEFAULT_SCOPE
	local apiBase = config.apiBase or DEFAULT_API_BASE

	local function baseParams(): { [string]: string }
		local params: { [string]: string } = {
			client_id = clientId,
		}
		return params
	end

	-- ────────────────────────────────────────────────────────
	-- OAuth2: Device code
	-- ────────────────────────────────────────────────────────

	--[[
		Request a new device code session.

		POST /oauth2/device/authorize

		On success, the caller should display the userCode and
		verificationUrlComplete to the user, then start polling
		with exchangeDeviceCodeAsync.
	]]
	local function requestDeviceCodeAsync(): Result.Result<DeviceCodeSession, DeviceCodeProblem>
		local params = baseParams()
		params.scope = scope

		local res = postFormAsync(`{apiBase}/oauth2/device/authorize`, params)
		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		if not res.value.ok then
			local err = oauthError(res.value.body)
			if err == "invalid_scope" then
				return Result.err<<InvalidScopeProblem>>({
					type = "invalid_scope",
					description = if type(res.value.body) == "table" then res.value.body.error_description else nil,
				})
			end
			return Result.err(unexpected(res.value))
		end

		local body = res.value.body
		if type(body) ~= "table" or not body.device_code then
			return Result.err(unexpected(res.value))
		end

		return Result.ok<<DeviceCodeSession>>({
			deviceCode = body.device_code,
			userCode = body.user_code,
			verificationUrl = body.verification_uri,
			verificationUrlComplete = body.verification_uri_complete,
			expiresIn = body.expires_in,
			interval = body.interval,
		})
	end

	--[[
		Exchange a device code for tokens (single poll attempt).

		POST /oauth2/token

		Returns the token on success, or a specific problem type
		for each known polling state. The caller is responsible for
		the poll loop timing — this function does exactly one request.
	]]
	local function exchangeDeviceCodeAsync(deviceCode: string): Result.Result<TokenResult, DeviceCodeExchangeProblem>
		local params = baseParams()
		params.grant_type = "urn:ietf:params:oauth:grant-type:device_code"
		params.device_code = deviceCode

		local res = postFormAsync(`{apiBase}/oauth2/token`, params)
		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		-- Success: tokens granted
		if res.ok and res.value.statusCode == 200 and type(res.value.body) == "table" then
			local body = res.value.body
			return Result.ok<<TokenResult>>({
				accessToken = body.access_token,
				refreshToken = body.refresh_token,
				expiresAt = os.time() + (body.expires_in or 604800),
				scope = body.scope,
				tokenType = body.token_type,
			})
		end

		-- Expected 400 errors during polling
		if res.value.statusCode == 400 then
			local err = oauthError(res.value.body)

			if err == "authorization_pending" then
				return Result.err<<AuthorizationPendingProblem>>({ type = "authorization_pending" })
			end
			if err == "slow_down" then
				return Result.err<<SlowDownProblem>>({ type = "slow_down" })
			end
			if err == "expired_token" then
				return Result.err<<ExpiredTokenProblem>>({ type = "expired_token" })
			end
			if err == "access_denied" then
				return Result.err<<AccessDeniedProblem>>({ type = "access_denied" })
			end
		end

		return Result.err(unexpected(res.value))
	end

	-- ────────────────────────────────────────────────────────
	-- OAuth2: Token refresh
	-- ────────────────────────────────────────────────────────

	--[[
		Refresh an access token.

		POST /oauth2/token
	]]
	local function refreshTokenAsync(refreshToken: string): Result.Result<TokenResult, RefreshProblem>
		local params = baseParams()
		params.grant_type = "refresh_token"
		params.refresh_token = refreshToken

		local res = postFormAsync(`{apiBase}/oauth2/token`, params)
		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		if res.ok and res.value.statusCode == 200 and type(res.value.body) == "table" then
			local body = res.value.body
			return Result.ok<<TokenResult>>({
				accessToken = body.access_token,
				refreshToken = body.refresh_token,
				expiresAt = os.time() + (body.expires_in or 604800),
				scope = body.scope,
				tokenType = body.token_type,
			})
		end

		if res.value.statusCode == 400 then
			local err = oauthError(res.value.body)
			if err == "invalid_grant" then
				return Result.err<<InvalidGrantProblem>>({ type = "invalid_grant" })
			end
		end

		return Result.err(unexpected(res.value))
	end

	-- ────────────────────────────────────────────────────────
	-- Users
	-- ────────────────────────────────────────────────────────

	--[[
		Get the current user's profile.

		GET /users/@me
	]]
	local function getCurrentUserAsync(accessToken: string): Result.Result<User, AuthenticatedProblem>
		local res = getJsonAuthAsync(`{apiBase}/users/@me`, accessToken)
		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		if res.value.statusCode == 401 then
			return Result.err<<UnauthorizedProblem>>({ type = "unauthorized" })
		end

		if res.value.ok and type(res.value.body) == "table" then
			local body = res.value.body
			return Result.ok<<User>>({
				id = body.id,
				username = body.username,
				globalName = body.global_name,
				avatar = body.avatar,
			})
		end

		return Result.err(unexpected(res.value))
	end

	--[[
		Download a user's avatar as a PNG image.

		GET https://cdn.discordapp.com/avatars/{user_id}/{avatar_hash}.png
		GET https://cdn.discordapp.com/embed/avatars/{index}.png (default)

		If the user has a custom avatar, fetches it from the CDN.
		If the user has no avatar (avatar is nil), fetches their
		default avatar based on their user ID.

		Returns the raw PNG bytes — suitable for use with
		EditableImage or writing to a file.

		Does not require an access token; the CDN is public.
	]]
	local function getUserAvatarAsync(user: User): Result.Result<AvatarImage, AvatarProblem>
		local CDN_BASE = "https://cdn.discordapp.com"
		local url: string

		if user.avatar then
			url = `{CDN_BASE}/avatars/{user.id}/{user.avatar}.png?size=128`
		else
			-- Default avatar index: (user_id >> 22) % 6
			-- Luau's tonumber on large snowflake strings may lose precision,
			-- but we only need the upper bits modulo 6 so we parse the
			-- high portion of the snowflake to avoid float truncation.
			local idNum = tonumber(user.id)
			local index = if idNum then math.floor(idNum / (2 ^ 22)) % 6 else 0
			url = `{CDN_BASE}/embed/avatars/{index}.png`
		end

		local requestOk, result = pcall(HttpService.RequestAsync, HttpService, {
			Url = url,
			Method = "GET" :: "GET",
			Compress = Enum.HttpCompression.None,
		})

		if not requestOk then
			return Result.err<<NetworkProblem>>({ type = "network", message = tostring(result) })
		end

		if not result.Success then
			return Result.err<<UnexpectedProblem>>({
				type = "unexpected",
				statusCode = result.StatusCode,
				body = nil,
			})
		end

		return Result.ok<<AvatarImage>>({
			data = result.Body or "",
			contentType = result.Headers["content-type"] or "image/png",
		})
	end

	-- ────────────────────────────────────────────────────────
	-- Application assets
	-- ────────────────────────────────────────────────────────

	--[[
		Get all assets registered for this application.

		GET /oauth2/applications/{clientId}/assets

		Public endpoint — no authentication required.
	]]
	local function getApplicationAssetsAsync(): Result.Result<{ ApplicationAsset }, ApplicationAssetsProblem>
		local res = getJsonAsync(`{apiBase}/oauth2/applications/{clientId}/assets`)
		if not res.ok then
			return Result.err(res.error)
		end

		if not res.value.ok or type(res.value.body) ~= "table" then
			return Result.err(unexpected(res.value))
		end

		local assets: { ApplicationAsset } = {}
		for _, raw in res.value.body do
			if type(raw) == "table" and raw.id and raw.name then
				table.insert(assets, {
					id = tostring(raw.id),
					name = raw.name,
					assetType = raw.type or 1,
				})
			end
		end

		return Result.ok(assets)
	end

	-- ────────────────────────────────────────────────────────
	-- Headless sessions (presence)
	-- ────────────────────────────────────────────────────────

	--[[
		Create a new headless presence session.

		POST /users/@me/headless-sessions

		The activity must include at minimum: type, name,
		application_id, and platform.

		Headless sessions expire after 20 minutes. Call
		updateHeadlessSessionAsync every ~15 minutes to keep
		the session alive.

		A 202 response means the application isn't cached yet
		on Discord's side — retry after the indicated delay.
	]]
	local function createHeadlessSessionAsync(
		accessToken: string,
		activity: Activity
	): Result.Result<HeadlessSession, HeadlessSessionCreateProblem>
		local res = postJsonAuthAsync(`{apiBase}/users/@me/headless-sessions`, {
			activities = { activity },
		}, accessToken)

		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		if res.value.statusCode == 401 then
			return Result.err<<UnauthorizedProblem>>({ type = "unauthorized" })
		end

		if res.value.statusCode == 429 and type(res.value.body) == "table" then
			return Result.err<<RateLimitedProblem>>({
				type = "rate_limited",
				retryAfter = res.value.body.retry_after or 5,
			})
		end

		-- Application not yet cached — caller should retry
		if res.value.statusCode == 202 and type(res.value.body) == "table" then
			return Result.err<<ApplicationNotCachedProblem>>({
				type = "application_not_cached",
				retryAfter = res.value.body.retry_after or 4000,
			})
		end

		if res.value.ok and type(res.value.body) == "table" then
			local body = res.value.body
			return Result.ok<<HeadlessSession>>({
				sessionToken = body.token,
				activities = body.activities,
			})
		end

		return Result.err(unexpected(res.value))
	end

	--[[
		Update (heartbeat) an existing headless session.

		POST /users/@me/headless-sessions

		Same endpoint as create, but with the session token
		included. The token may rotate — always use the one
		from the response for subsequent calls.
	]]
	local function updateHeadlessSessionAsync(
		accessToken: string,
		sessionToken: string,
		activity: Activity
	): Result.Result<HeadlessSession, AuthenticatedProblem>
		local res = postJsonAuthAsync(`{apiBase}/users/@me/headless-sessions`, {
			token = sessionToken,
			activities = { activity },
		}, accessToken)

		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		if res.value.statusCode == 401 then
			return Result.err<<UnauthorizedProblem>>({ type = "unauthorized" })
		end

		if res.value.statusCode == 429 and type(res.value.body) == "table" then
			return Result.err<<RateLimitedProblem>>({
				type = "rate_limited",
				retryAfter = res.value.body.retry_after or 5,
			})
		end

		if res.value.ok and type(res.value.body) == "table" then
			local body = res.value.body
			return Result.ok<<HeadlessSession>>({
				sessionToken = body.token,
				activities = body.activities,
			})
		end

		return Result.err(unexpected(res.value))
	end

	--[[
		Delete a headless session.

		POST /users/@me/headless-sessions/delete
	]]
	local function deleteHeadlessSessionAsync(
		accessToken: string,
		sessionToken: string
	): Result.Result<nil, AuthenticatedProblem>
		local res =
			postJsonAuthAsync(`{apiBase}/users/@me/headless-sessions/delete`, { token = sessionToken }, accessToken)

		if not res.ok then
			-- Network error
			return Result.err(res.error)
		end

		if res.value.statusCode == 401 then
			return Result.err<<UnauthorizedProblem>>({ type = "unauthorized" })
		end

		if res.value.statusCode == 429 and type(res.value.body) == "table" then
			return Result.err<<RateLimitedProblem>>({
				type = "rate_limited",
				retryAfter = res.value.body.retry_after or 5,
			})
		end

		-- 204 No Content is the expected success
		if res.value.ok then
			return Result.ok(nil)
		end

		return Result.err(unexpected(res.value))
	end

	-- ────────────────────────────────────────────────────────

	return table.freeze({
		requestDeviceCodeAsync = requestDeviceCodeAsync,
		exchangeDeviceCodeAsync = exchangeDeviceCodeAsync,
		refreshTokenAsync = refreshTokenAsync,
		getCurrentUserAsync = getCurrentUserAsync,
		getUserAvatarAsync = getUserAvatarAsync,
		getApplicationAssetsAsync = getApplicationAssetsAsync,
		createHeadlessSessionAsync = createHeadlessSessionAsync,
		updateHeadlessSessionAsync = updateHeadlessSessionAsync,
		deleteHeadlessSessionAsync = deleteHeadlessSessionAsync,
	})
end

export type DiscordApi = typeof(new(nil :: any))

return table.freeze({
	new = new,
})
