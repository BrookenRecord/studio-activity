local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Signal = require(Packages.Signal)

local Logger = require(Plugin.Source.Logger)

local Api = Plugin.Source.Api
local ApiClient = require(Api.Api)
local Result = require(Api.Result)

type ApiError = ApiClient.ApiError
type Result<T, E> = Result.Result<T, E>
type Signal<T> = Signal.Signal<T>

export type AuthSessionState = "idle" | "started" | "completed" | "failed" | "expired"

type AuthSessionProps = {
	apiClient: ApiClient.ApiClient,
}

local function _createSseConnection(url: string)
	local sseClient = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.SSE, {
		Url = url,
	})

	sseClient.MessageReceived:Connect(function(eventType: string, data: string)
		Logger:Debug("AuthSession SSE message received", { eventType = eventType, data = data })
	end)

	return sseClient
end

local AuthSession = {}
AuthSession.__index = AuthSession

function AuthSession.new(props: AuthSessionProps)
	local self = setmetatable({}, AuthSession)

	self.OnStateChanged = Signal.new() :: Signal<AuthSessionState>

	self._apiClient = props.apiClient
	self._authCode = nil :: string?
	self._state = "idle" :: AuthSessionState

	return self
end

export type AuthSession = typeof(AuthSession.new(...))

function AuthSession.GetState(self: AuthSession): AuthSessionState
	return self._state :: AuthSessionState
end

function AuthSession._updateState(self: AuthSession, state: AuthSessionState)
	if self._state == state then
		return
	end

	Logger:Debug("AuthSession state changed", { state = state })

	self._state = state
	self.OnStateChanged:Fire(state)
end

type StartResult = {
	url: string,
}

function AuthSession.Start(self: AuthSession): Result<StartResult, ApiError>
	local result = self._apiClient:AuthStart()
	if result.ok then
		self._authCode = result.value.code
		self:_updateState("started")

		return Result.ok({
			url = result.value.url,
		})
	else
		return result
	end
end

return {
	new = AuthSession.new,
}
