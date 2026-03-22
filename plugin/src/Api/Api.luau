local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Api = Plugin.Source.Api
local Protos = Api.Protos
local CredentialsStore = require(Api.CredentialsStore)
local HttpClient = require(Api.HttpClient)
local Logger = require(Plugin.Source.Logger)
local Result = require(Api.Result)
local fireEventAsync = require(Plugin.Source.Telemetry.fireEventAsync)

local createPluginSettingsStore = require(Plugin.Source.Plugin.createPluginSettingsStore)

-- Import protobuf types
local accounts = require(Protos.accounts)
local auth = require(Protos.auth)
local common = require(Protos.common)
local presence = require(Protos.presence)

-- Re-export protobuf types for convenience
export type AuthStartRequest = auth.AuthStartRequest
export type AuthStartResponse = auth.AuthStartResponse
export type AuthCompleteRequest = auth.AuthCompleteRequest
export type AuthCompleteResponse = auth.AuthCompleteResponse

export type ListAccountsResponse = accounts.ListAccountsResponse
export type LinkedAccount = accounts.LinkedAccount

export type UpdatePresenceRequest = presence.UpdatePresenceRequest
export type UpdatePresenceResponse = presence.UpdatePresenceResponse
export type ClearPresenceRequest = presence.ClearPresenceRequest
export type ClearPresenceResponse = presence.ClearPresenceResponse
export type DiscordPresence = presence.DiscordPresence
export type PresenceTimestamps = presence.PresenceTimestamps
export type PresenceAssets = presence.PresenceAssets

export type ErrorResponse = common.ErrorResponse
export type ErrorCode = common.ErrorCode

-- Re-export credentials type
export type Credentials = CredentialsStore.Credentials

-- API Error type that wraps HTTP errors with API-specific information
export type ApiErrorType = "NetworkError" | "HttpError" | "RateLimited" | "ApiError" | "ParseError"

-- The ErrorCode from protobuf is a union of string literals and number (for unknown codes)
-- We widen to (string | number)? since we can't guarantee which specific code we get
export type ApiError = {
	-- Error type
	type: ApiErrorType,
	-- Error code from API response (if available)
	code: (string | number)?,
	-- Error message
	message: string,
	-- HTTP status code (if applicable)
	statusCode: number?,
	-- Seconds until retry is allowed (for rate limits)
	retryAfter: number?,
	-- Additional error details from API
	details: { [string]: string }?,
}

-- Configuration for the API client
export type ApiConfig = {
	--- Base URL for the API (e.g., "https://srp.example.com")
	baseUrl: string,
	--- Maximum number of retry attempts (default: 3)
	maxRetries: number?,
}

-- Internal type with private fields
type ApiClientInternal = {
	_httpClient: HttpClient.HttpClient,
	_credentialsStore: createPluginSettingsStore.PluginSettingsStore<Credentials>,
}

-- The API client type (public interface)
export type ApiClient = {
	-- Check if credentials are stored
	HasCredentials: (self: ApiClient) -> boolean,

	-- Get stored credentials (or nil if none)
	GetCredentials: (self: ApiClient) -> Credentials,

	-- Clear stored credentials
	ClearCredentials: (self: ApiClient) -> (),

	-- Auth endpoints
	AuthStart: (self: ApiClient) -> Result.Result<AuthStartResponse, ApiError>,

	AuthComplete: (
		self: ApiClient,
		request: { code: string, completionCode: string }
	) -> Result.Result<AuthCompleteResponse, ApiError>,

	-- Presence endpoints (require credentials)
	UpdatePresence: (
		self: ApiClient,
		presenceData: DiscordPresence?,
		ackToken: string?
	) -> Result.Result<UpdatePresenceResponse, ApiError>,

	ClearPresence: (self: ApiClient) -> Result.Result<ClearPresenceResponse, ApiError>,

	-- Account endpoints (require credentials)
	ListAccounts: (self: ApiClient) -> Result.Result<ListAccountsResponse, ApiError>,
}

-- Combined type for internal use
type ApiClientImpl = ApiClient & ApiClientInternal

local ApiClientClass = {}
ApiClientClass.__index = ApiClientClass

--[[
	Parses an API error response body.
]]
local function parseApiError(body: string): ErrorResponse?
	local success, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not success or typeof(decoded) ~= "table" then
		return nil
	end

	-- Try to decode as ErrorResponse
	local ok, errorResponse = pcall(function()
		return common.ErrorResponse.jsonDecode(decoded)
	end)

	if ok then
		return errorResponse
	end

	return nil
end

--[[
	Converts an HTTP error to an API error.
]]
local function httpErrorToApiError(httpError: HttpClient.HttpError): ApiError
	-- Try to parse API error from response body
	local errorResponse: ErrorResponse? = nil
	if httpError.responseBody then
		errorResponse = parseApiError(httpError.responseBody)
	end

	if httpError.type == "RateLimited" then
		local err: ApiError = {
			type = "RateLimited" :: ApiErrorType,
			code = if errorResponse then errorResponse.code else nil,
			message = if errorResponse then errorResponse.message else "Rate limited",
			statusCode = httpError.statusCode,
			retryAfter = httpError.retryAfter,
			details = if errorResponse then errorResponse.details else nil,
		}
		return err
	end

	if httpError.type == "NetworkError" or httpError.type == "Timeout" then
		local err: ApiError = {
			type = "NetworkError" :: ApiErrorType,
			message = httpError.message,
		}
		return err
	end

	-- HTTP error with possible API error response
	if errorResponse then
		local err: ApiError = {
			type = "ApiError" :: ApiErrorType,
			code = errorResponse.code,
			message = errorResponse.message,
			statusCode = httpError.statusCode,
			details = errorResponse.details,
		}
		return err
	end

	local err: ApiError = {
		type = "HttpError" :: ApiErrorType,
		message = httpError.message,
		statusCode = httpError.statusCode,
	}
	return err
end

--[[
	Decodes a JSON response body into the specified type.
]]
local function decodeResponse<T>(body: string, decoder: (input: { [string]: any }) -> T): Result.Result<T, ApiError>
	local success, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not success then
		Logger:Warn("Failed to parse JSON response", { error = tostring(decoded) })
		local err: ApiError = {
			type = "ParseError" :: ApiErrorType,
			message = `Failed to parse JSON: {decoded}`,
		}
		return Result.err(err)
	end

	local ok, result = pcall(function()
		return decoder(decoded)
	end)

	if not ok then
		Logger:Warn("Failed to decode response", { error = tostring(result) })
		local err: ApiError = {
			type = "ParseError" :: ApiErrorType,
			message = `Failed to decode response: {result}`,
		}
		return Result.err(err)
	end

	return Result.ok(result)
end

--[[
	Reports an API error via telemetry.
]]
local function reportApiError(endpoint: string, apiError: ApiError)
	task.spawn(function()
		if apiError.type == "RateLimited" then
			fireEventAsync({
				eventName = "RateLimited",
				properties = {
					endpoint = endpoint,
					retryAfter = apiError.retryAfter,
				},
			})
		else
			fireEventAsync({
				eventName = "ApiError",
				properties = {
					endpoint = endpoint,
					errorType = apiError.type :: string,
					statusCode = apiError.statusCode,
				},
			})
		end
	end)
end

--[[
	Creates a new API client instance.
]]
function ApiClientClass.new(config: ApiConfig): ApiClient
	Logger:Info("Creating new ApiClient", { baseUrl = config.baseUrl })

	local internal: ApiClientInternal = {
		_httpClient = HttpClient.new({
			baseUrl = config.baseUrl,
			defaultHeaders = {
				["Content-Type"] = "application/json",
			},
			maxRetries = config.maxRetries,
		}),
		_credentialsStore = CredentialsStore.get(),
	}

	return setmetatable(internal :: any, ApiClientClass) :: ApiClient
end

--[[
	Checks if credentials are stored.
]]
function ApiClientClass.HasCredentials(self: ApiClient): boolean
	local impl = self :: ApiClientImpl
	local creds = impl._credentialsStore.getStorage()
	local hasCredentials = creds.authToken ~= nil and creds.clientKey ~= nil
	Logger:Debug("HasCredentials check", { hasCredentials = hasCredentials })
	return hasCredentials
end

--[[
	Gets the stored credentials.
]]
function ApiClientClass.GetCredentials(self: ApiClient): Credentials
	local impl = self :: ApiClientImpl
	return impl._credentialsStore.getStorage()
end

--[[
	Clears stored credentials.
]]
function ApiClientClass.ClearCredentials(self: ApiClient): ()
	local impl = self :: ApiClientImpl
	Logger:Info("Clearing stored credentials")
	impl._credentialsStore.setStorage({
		authToken = nil,
		clientKey = nil,
	})
end

--[[
	Asserts that credentials are available and returns them.
	Throws an error if no credentials are stored.
]]
local function requireCredentials(impl: ApiClientImpl): (string, string)
	local creds = impl._credentialsStore.getStorage()
	if creds.authToken == nil or creds.clientKey == nil then
		Logger:Error("No credentials stored - operation requires authentication")
		error("No credentials stored. Call AuthComplete first to link a Discord account.")
	end
	return creds.authToken, creds.clientKey
end

--[[
	POST /auth/start

	Initiates the Discord linking flow.
	If credentials are stored, uses them to link an additional account.

	@return AuthStartResponse on success, ApiError on failure
]]
function ApiClientClass.AuthStart(self: ApiClient): Result.Result<AuthStartResponse, ApiError>
	local impl = self :: ApiClientImpl

	-- Build request body - use existing credentials if available
	local bodyData: { [string]: any } = {}
	local creds = impl._credentialsStore.getStorage()
	local hasExistingCredentials = creds.authToken ~= nil and creds.clientKey ~= nil

	if hasExistingCredentials then
		Logger:Info("Starting auth flow with existing credentials (linking additional account)")
		bodyData.authToken = creds.authToken
		bodyData.clientKey = creds.clientKey
	else
		Logger:Info("Starting auth flow for new user")
	end

	-- Fire telemetry
	task.spawn(function()
		fireEventAsync({
			eventName = "AuthStarted",
			properties = {
				hasExistingCredentials = hasExistingCredentials,
			},
		})
	end)

	local body = HttpService:JSONEncode(bodyData)
	local result = impl._httpClient:Post("/auth/start", body)

	if not result.ok then
		local apiError = httpErrorToApiError(result.error)
		Logger:Warn("Auth start failed", { errorType = apiError.type, message = apiError.message })
		reportApiError("/auth/start", apiError)
		return Result.err(apiError)
	end

	local decodeResult = decodeResponse(result.value.body, auth.AuthStartResponse.jsonDecode)
	if decodeResult.ok then
		Logger:Info("Auth start successful", { code = decodeResult.value.code })
	end

	return decodeResult
end

--[[
	POST /auth/complete

	Completes the auth flow using the completion code.
	Stores credentials on successful completion for new users.

	@param request The session code and 5-digit completion code
	@return AuthCompleteResponse on success (may be empty for existing users), ApiError on failure
]]
function ApiClientClass.AuthComplete(
	self: ApiClient,
	request: { code: string, completionCode: string }
): Result.Result<AuthCompleteResponse, ApiError>
	local impl = self :: ApiClientImpl

	Logger:Info("Completing auth flow", { code = request.code })

	local body = HttpService:JSONEncode({
		code = request.code,
		completionCode = request.completionCode,
	})

	local result = impl._httpClient:Post("/auth/complete", body)

	if not result.ok then
		local apiError = httpErrorToApiError(result.error)
		Logger:Warn("Auth complete failed", { errorType = apiError.type, message = apiError.message })

		-- Fire telemetry for auth failure
		task.spawn(function()
			fireEventAsync({
				eventName = "AuthFailed",
				properties = {
					errorType = apiError.type :: string,
					errorCode = if apiError.code then tostring(apiError.code) else nil,
				},
			})
		end)

		reportApiError("/auth/complete", apiError)
		return Result.err(apiError)
	end

	local decodeResult = decodeResponse(result.value.body, auth.AuthCompleteResponse.jsonDecode)

	-- Store credentials if returned (new users only)
	if decodeResult.ok then
		local response = decodeResult.value
		local isNewUser = response.auth_token ~= nil and response.client_key ~= nil

		if isNewUser then
			Logger:Info("Auth complete successful - storing credentials for new user")
			impl._credentialsStore.setStorage({
				authToken = response.auth_token,
				clientKey = response.client_key,
			})
		else
			Logger:Info("Auth complete successful - existing user linked additional account")
		end

		-- Fire telemetry for successful auth
		task.spawn(function()
			fireEventAsync({
				eventName = "AuthCompleted",
				properties = {
					isNewUser = isNewUser,
				},
			})
		end)
	end

	return decodeResult
end

--[[
	POST /presence/update

	Updates Discord presence for all linked accounts.
	Requires stored credentials.

	@param presenceData Optional presence data to set
	@param ackToken Optional acknowledgment token from previous response
	@return UpdatePresenceResponse on success, ApiError on failure
]]
function ApiClientClass.UpdatePresence(
	self: ApiClient,
	presenceData: DiscordPresence?,
	ackToken: string?
): Result.Result<UpdatePresenceResponse, ApiError>
	local impl = self :: ApiClientImpl
	local authToken, clientKey = requireCredentials(impl)

	Logger:Debug("Updating presence", { hasPresenceData = presenceData ~= nil, hasAckToken = ackToken ~= nil })

	-- Build headers
	local headers: HttpClient.HttpHeaders = {
		["Authorization"] = `Bearer {authToken}`,
		["X-Client-Key"] = clientKey,
	}

	if ackToken then
		headers["X-Ack-Token"] = ackToken
	end

	-- Build body with presence
	local bodyData: { [string]: any } = {}
	if presenceData then
		bodyData.presence = presenceData:jsonEncode()
	end

	local body = HttpService:JSONEncode(bodyData)

	local result = impl._httpClient:Request({
		url = "/presence/update",
		method = "POST",
		headers = headers,
		body = body,
	})

	if not result.ok then
		local apiError = httpErrorToApiError(result.error)
		Logger:Warn("Presence update failed", { errorType = apiError.type, message = apiError.message })
		reportApiError("/presence/update", apiError)
		return Result.err(apiError)
	end

	local decodeResult = decodeResponse(result.value.body, presence.UpdatePresenceResponse.jsonDecode)

	if decodeResult.ok then
		local response = decodeResult.value
		local updatedCount = response.updated_accounts or 0
		local failedCount = response.failed_accounts or 0

		Logger:Debug("Presence update successful", { updatedCount = updatedCount, failedCount = failedCount })

		-- Fire telemetry
		task.spawn(function()
			fireEventAsync({
				eventName = "PresenceUpdated",
				properties = {
					updatedCount = updatedCount,
					failedCount = failedCount,
				},
			})
		end)
	end

	return decodeResult
end

--[[
	POST /presence/clear

	Clears Discord presence for all linked accounts.
	Requires stored credentials.

	@return ClearPresenceResponse on success, ApiError on failure
]]
function ApiClientClass.ClearPresence(self: ApiClient): Result.Result<ClearPresenceResponse, ApiError>
	local impl = self :: ApiClientImpl
	local authToken, clientKey = requireCredentials(impl)

	Logger:Debug("Clearing presence")

	local headers: HttpClient.HttpHeaders = {
		["Authorization"] = `Bearer {authToken}`,
		["X-Client-Key"] = clientKey,
	}

	local result = impl._httpClient:Request({
		url = "/presence/clear",
		method = "POST",
		headers = headers,
		body = "{}",
	})

	if not result.ok then
		local apiError = httpErrorToApiError(result.error)
		Logger:Warn("Presence clear failed", { errorType = apiError.type, message = apiError.message })
		reportApiError("/presence/clear", apiError)
		return Result.err(apiError)
	end

	local decodeResult = decodeResponse(result.value.body, presence.ClearPresenceResponse.jsonDecode)

	if decodeResult.ok then
		local response = decodeResult.value
		local clearedCount = response.cleared_accounts or 0
		local failedCount = response.failed_accounts or 0

		Logger:Debug("Presence clear successful", { clearedCount = clearedCount, failedCount = failedCount })

		-- Fire telemetry
		task.spawn(function()
			fireEventAsync({
				eventName = "PresenceCleared",
				properties = {
					clearedCount = clearedCount,
					failedCount = failedCount,
				},
			})
		end)
	end

	return decodeResult
end

--[[
	GET /accounts

	Lists all linked Discord accounts for the authenticated user.
	Requires stored credentials.

	@return ListAccountsResponse on success, ApiError on failure
]]
function ApiClientClass.ListAccounts(self: ApiClient): Result.Result<ListAccountsResponse, ApiError>
	local impl = self :: ApiClientImpl
	local authToken, clientKey = requireCredentials(impl)

	Logger:Debug("Listing accounts")

	local headers: HttpClient.HttpHeaders = {
		["Authorization"] = `Bearer {authToken}`,
		["X-Client-Key"] = clientKey,
	}

	local result = impl._httpClient:Request({
		url = "/accounts",
		method = "GET",
		headers = headers,
	})

	if not result.ok then
		local apiError = httpErrorToApiError(result.error)
		Logger:Warn("List accounts failed", { errorType = apiError.type, message = apiError.message })
		reportApiError("/accounts", apiError)
		return Result.err(apiError)
	end

	local decodeResult = decodeResponse(result.value.body, accounts.ListAccountsResponse.jsonDecode)

	if decodeResult.ok then
		local response = decodeResult.value
		local accountCount = if response.accounts then #response.accounts else 0
		Logger:Debug("List accounts successful", { accountCount = accountCount })
	end

	return decodeResult
end

-- Export the module
local ApiModule = {
	-- Client constructor
	new = ApiClientClass.new,

	-- Re-export Result utilities for convenience
	Result = Result,

	-- Re-export protobuf constructors
	AuthStartRequest = auth.AuthStartRequest,
	AuthStartResponse = auth.AuthStartResponse,
	AuthCompleteRequest = auth.AuthCompleteRequest,
	AuthCompleteResponse = auth.AuthCompleteResponse,
	AuthEventType = auth.AuthEventType,

	ListAccountsRequest = accounts.ListAccountsRequest,
	ListAccountsResponse = accounts.ListAccountsResponse,
	LinkedAccount = accounts.LinkedAccount,

	UpdatePresenceRequest = presence.UpdatePresenceRequest,
	UpdatePresenceResponse = presence.UpdatePresenceResponse,
	ClearPresenceRequest = presence.ClearPresenceRequest,
	ClearPresenceResponse = presence.ClearPresenceResponse,
	DiscordPresence = presence.DiscordPresence,
	PresenceTimestamps = presence.PresenceTimestamps,
	PresenceAssets = presence.PresenceAssets,

	ErrorResponse = common.ErrorResponse,
	ErrorCode = common.ErrorCode,
}

return ApiModule
