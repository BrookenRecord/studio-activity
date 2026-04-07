--[[
	DeviceCodeFlow

	Implements the Discord device code OAuth2 grant for Studio plugins.
	Exposes reactive charm signals for driving UI updates.

	The flow is fully restartable — calling requestAsync() again cancels
	any in-progress polling and starts fresh with a new device code.

	Usage:

		local flow = DeviceCodeFlow.create({
			discord = DiscordApi.new({ clientId = "YOUR_CLIENT_ID" }),
		})

		-- Start or restart the flow (can be called multiple times)
		flow.requestAsync()

		-- UI reads state via charm signals:
		--   flow.status()       → "idle" | "requesting" | "polling" | "authorized" | "denied" | "expired" | "error"
		--   flow.sessionInfo()  → SessionInfo? (available once status is "polling")
		--   flow.error()        → string? (available when status is "error")

		-- Cleanup when done
		flow.destroy()
]]

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local AccountStore = require(script.Parent.Parent.AccountStore)
local DiscordApi = require(Plugin.Source.Api.Discord)
local Telemetry = require(Plugin.Source.Telemetry.fireEventAsync)
local Types = require(Plugin.Source.Telemetry.Types)

local signal = Charm.signal
local batch = Charm.batch

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
	discord: DiscordApi.DiscordApi,
}

--[[ Module ]]

local function create(config: Config)
	local discord = config.discord

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
		-- Phase 1: Request device code
		batch(function()
			setStatus("requesting")
			setErrorMessage(nil)
		end)

		local deviceResult = discord.requestDeviceCodeAsync()

		if not deviceResult.ok then
			local err = deviceResult.error
			local message: string
			if err.type == "network" then
				message = err.message
			elseif err.type == "invalid_scope" then
				message = err.description or "Invalid OAuth scope"
			else
				message = `Request failed ({err.statusCode})`
			end

			Telemetry.fireEvent({
				type = "deviceCodeFlowFailed",
				value = Types.DeviceCodeFlowFailed.new({ error = err.type :: string }),
			})

			batch(function()
				setStatus("error")
				setErrorMessage(message)
			end)
			return
		end

		local session = deviceResult.value
		local info: SessionInfo = {
			deviceCode = session.deviceCode,
			userCode = session.userCode,
			verificationUrl = session.verificationUrl,
			verificationUrlComplete = session.verificationUrlComplete,
			expiresIn = session.expiresIn,
			interval = session.interval,
		}

		batch(function()
			setStatus("polling")
			setSessionInfo(info)
		end)

		-- Phase 2: Poll for token
		local interval = math.clamp(info.interval, MIN_POLL_INTERVAL, MAX_POLL_INTERVAL)
		local deadline = os.time() + info.expiresIn

		while os.time() < deadline do
			task.wait(interval)

			local pollResult = discord.exchangeDeviceCodeAsync(info.deviceCode)

			if pollResult.ok then
				local token = pollResult.value
				local addOk = accountStore.addUserAsync({
					accessToken = token.accessToken,
					refreshToken = token.refreshToken or "",
					expiresAt = token.expiresAt,
				}, "ACCOUNT_LINK_FLOW_DEVICE_CODE")

				if addOk then
					setStatus("authorized")
				else
					Telemetry.fireEvent({
						type = "deviceCodeFlowFailed",
						value = Types.DeviceCodeFlowFailed.new({ error = "add_user_failed" }),
					})
					batch(function()
						setStatus("error")
						setErrorMessage("Failed to link account")
					end)
				end
				return
			end

			local errType = pollResult.error.type

			if errType == "authorization_pending" then
				continue
			end

			if errType == "slow_down" then
				interval = math.min(interval + 1, MAX_POLL_INTERVAL)
				continue
			end

			if errType == "expired_token" then
				Telemetry.fireEvent({
					type = "deviceCodeFlowFailed",
					value = Types.DeviceCodeFlowFailed.new({ error = "expired" }),
				})
				batch(function()
					setStatus("expired")
					setSessionInfo(nil)
				end)
				return
			end

			if errType == "access_denied" then
				Telemetry.fireEvent({
					type = "deviceCodeFlowFailed",
					value = Types.DeviceCodeFlowFailed.new({ error = "denied" }),
				})
				batch(function()
					setStatus("denied")
					setSessionInfo(nil)
				end)
				return
			end

			-- Network or unexpected error — stop polling
			local message: string
			if errType == "network" then
				message = (pollResult.error :: DiscordApi.NetworkProblem).message
			else
				message = `Polling failed ({(pollResult.error :: DiscordApi.UnexpectedProblem).statusCode})`
			end

			Telemetry.fireEvent({
				type = "deviceCodeFlowFailed",
				value = Types.DeviceCodeFlowFailed.new({ error = errType }),
			})

			batch(function()
				setStatus("error")
				setErrorMessage(message)
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

export type DeviceCodeFlow = typeof(create(nil :: any))

return table.freeze({
	create = create,
})
