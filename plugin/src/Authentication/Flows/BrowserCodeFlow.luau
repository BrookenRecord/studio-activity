--[[
	BrowserCodeFlow

	Implements the Discord OAuth2 Authorization Code + PKCE grant for
	Studio plugins. Mirrors the public API of DeviceCodeFlow so the UI
	can consume both flows interchangeably.

	The plugin generates a code verifier+challenge locally; only the
	challenge is ever sent to the backend. After the user approves in
	their browser, the plugin claims the resulting authorization code
	from the backend and exchanges it directly with Discord — the
	backend never sees the verifier or any tokens.

	Usage:

		local flow = BrowserCodeFlow.create({
			discord = DiscordApi.new({ clientId = "YOUR_CLIENT_ID" }),
			backend = BackendApi.new(BuildVars.api),
		})

		flow.requestAsync()

		--   flow.status()       → "idle" | "requesting" | "polling" | "exchanging" | "authorized" | "denied" | "expired" | "error"
		--   flow.sessionInfo()  → SessionInfo? (available once status is "polling")
		--   flow.error()        → string? (available when status is "error")

		flow.destroy()
]]

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local AccountStore = require(script.Parent.Parent.AccountStore)
local BackendApi = require(Plugin.Source.Api.Backend)
local DiscordApi = require(Plugin.Source.Api.Discord)
local Pkce = require(script.Parent.Parent.Pkce)
local Telemetry = require(Plugin.Source.Telemetry.fireEventAsync)
local Types = require(Plugin.Source.Telemetry.Types)

local signal = Charm.signal
local batch = Charm.batch

-- Polling bounds to protect against server misconfig or bugs
local MIN_POLL_INTERVAL = 1
local MAX_POLL_INTERVAL = 30

--[[ Types ]]

export type Status = "idle" | "requesting" | "polling" | "exchanging" | "authorized" | "denied" | "expired" | "error"

export type SessionInfo = {
	startUrl: string,
	expiresIn: number,
	pollInterval: number,
}

export type Config = {
	discord: DiscordApi.DiscordApi,
	backend: BackendApi.BackendApi,
}

--[[ Module ]]

local function create(config: Config)
	local discord = config.discord
	local backend = config.backend

	-- Reactive state
	local status, setStatus = signal("idle" :: Status)
	local sessionInfo, setSessionInfo = signal(nil :: SessionInfo?)
	local errorMessage, setErrorMessage = signal(nil :: string?)

	local accountStore = AccountStore.get()

	-- Active thread tracking for cancellation
	local activeThread: thread? = nil

	local function cancelActive()
		if activeThread then
			pcall(task.cancel, activeThread)
			activeThread = nil
		end
	end

	local function resetState()
		batch(function()
			setStatus("idle")
			setSessionInfo(nil)
			setErrorMessage(nil)
		end)
	end

	local function flowAsync()
		-- Phase 1: Generate PKCE pair and ask the backend for a session.
		batch(function()
			setStatus("requesting")
			setErrorMessage(nil)
		end)

		local keys = Pkce.generate()

		local startResult = backend.startBrowserFlowAsync(keys.codeChallenge)
		if not startResult.ok then
			local err = startResult.error
			local message: string
			if err.type == "network" then
				message = err.message
			elseif err.type == "validation" then
				message = err.message or "Invalid request"
			else
				message = `Backend request failed ({err.statusCode})`
			end

			Telemetry.fireEvent({
				type = "browserFlowFailed",
				value = Types.BrowserFlowFailed.new({ error = err.type :: string }),
			})

			batch(function()
				setStatus("error")
				setErrorMessage(message)
			end)
			return
		end

		local startResponse = startResult.value
		local info: SessionInfo = {
			startUrl = startResponse.startUrl,
			expiresIn = startResponse.expiresIn,
			pollInterval = startResponse.pollInterval,
		}

		batch(function()
			setStatus("polling")
			setSessionInfo(info)
		end)

		-- Phase 2: Poll the backend until the user finishes (or we time out).
		local interval = math.clamp(info.pollInterval, MIN_POLL_INTERVAL, MAX_POLL_INTERVAL)
		local deadline = os.time() + info.expiresIn

		local authCode: string? = nil

		while os.time() < deadline do
			task.wait(interval)

			local pollResult = backend.pollBrowserFlowAsync(startResponse.sessionToken)

			if not pollResult.ok then
				local err = pollResult.error
				local message: string
				if err.type == "network" then
					message = err.message
				elseif err.type == "validation" then
					message = err.message or "Polling rejected"
				else
					message = `Polling failed ({err.statusCode})`
				end

				Telemetry.fireEvent({
					type = "browserFlowFailed",
					value = Types.BrowserFlowFailed.new({ error = err.type :: string }),
				})

				batch(function()
					setStatus("error")
					setErrorMessage(message)
				end)
				return
			end

			local pollStatus = pollResult.value.status

			if pollStatus == "BROWSER_FLOW_STATUS_PENDING" then
				continue
			end

			if pollStatus == "BROWSER_FLOW_STATUS_DENIED" then
				Telemetry.fireEvent({
					type = "browserFlowFailed",
					value = Types.BrowserFlowFailed.new({ error = "denied" }),
				})
				batch(function()
					setStatus("denied")
					setSessionInfo(nil)
				end)
				return
			end

			if pollStatus == "BROWSER_FLOW_STATUS_EXPIRED" then
				Telemetry.fireEvent({
					type = "browserFlowFailed",
					value = Types.BrowserFlowFailed.new({ error = "expired" }),
				})
				batch(function()
					setStatus("expired")
					setSessionInfo(nil)
				end)
				return
			end

			if pollStatus == "BROWSER_FLOW_STATUS_COMPLETE" then
				authCode = pollResult.value.code
				break
			end

			-- Unknown status code — treat as a hard failure.
			Telemetry.fireEvent({
				type = "browserFlowFailed",
				value = Types.BrowserFlowFailed.new({ error = "unknown_status" }),
			})
			batch(function()
				setStatus("error")
				setErrorMessage("Unexpected status from server")
			end)
			return
		end

		if authCode == nil then
			-- Fell through the loop — code never arrived in time.
			Telemetry.fireEvent({
				type = "browserFlowFailed",
				value = Types.BrowserFlowFailed.new({ error = "expired" }),
			})
			batch(function()
				setStatus("expired")
				setSessionInfo(nil)
			end)
			return
		end

		-- Phase 3: Exchange the code+verifier directly with Discord.
		batch(function()
			setStatus("exchanging")
			setSessionInfo(nil)
		end)

		local tokenResult =
			discord.exchangeAuthorizationCodeAsync(authCode, keys.codeVerifier, startResponse.redirectUri)

		if not tokenResult.ok then
			local err = tokenResult.error
			local message: string
			if err.type == "network" then
				message = err.message
			elseif err.type == "invalid_request" then
				message = err.description or "Invalid request to Discord"
			elseif err.type == "invalid_client" then
				message = "Discord rejected the client"
			elseif err.type == "invalid_grant" then
				message = "Authorization code was invalid or expired"
			else
				message = `Token exchange failed ({err.statusCode})`
			end

			Telemetry.fireEvent({
				type = "browserFlowFailed",
				value = Types.BrowserFlowFailed.new({ error = err.type :: string }),
			})

			batch(function()
				setStatus("error")
				setErrorMessage(message)
			end)
			return
		end

		-- Phase 4: Persist the linked account.
		local token = tokenResult.value
		local addOk = accountStore.addUserAsync({
			accessToken = token.accessToken,
			refreshToken = token.refreshToken or "",
			expiresAt = token.expiresAt,
		}, "ACCOUNT_LINK_FLOW_BROWSER")

		if addOk then
			setStatus("authorized")
		else
			Telemetry.fireEvent({
				type = "browserFlowFailed",
				value = Types.BrowserFlowFailed.new({ error = "add_user_failed" }),
			})
			batch(function()
				setStatus("error")
				setErrorMessage("Failed to link account")
			end)
		end
	end

	--[[ Public API ]]

	local function requestAsync()
		cancelActive()
		resetState()

		activeThread = task.defer(function()
			flowAsync()
			activeThread = nil
		end)
	end

	local function destroy()
		cancelActive()
		resetState()
	end

	return table.freeze({
		status = status,
		sessionInfo = sessionInfo,
		error = errorMessage,

		requestAsync = requestAsync,
		destroy = destroy,
	})
end

export type BrowserCodeFlow = typeof(create(nil :: any))

return table.freeze({
	create = create,
})
