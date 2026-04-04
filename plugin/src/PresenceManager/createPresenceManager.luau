local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local DiscordApi = require(Plugin.Source.Api.Discord)
type ApiActivity = DiscordApi.Activity

local AuthStore = require(Plugin.Source.Authentication.AuthStore)
local BuildVars = require(Plugin.Source.BuildVars)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local Logger = require(Plugin.Source.Logger)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local RetryBackoff = require(Plugin.Source.Api.RetryBackoff)

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect
local peek = Charm.peek

local HEARTBEAT_INTERVAL = 900 -- 15 minutes in seconds
local SYNC_DEBOUNCE_SECONDS = 1.5
local MAX_RETRIES = 3

export type ActivityConfigAssets = {
	largeImage: string?,
	largeText: string?,
	smallImage: string?,
	smallText: string?,
}

export type ActivityConfig = {
	name: string,
	details: string?,
	detailsUrl: string?,
	state: string?,
	stateUrl: string?,
	startedAt: number?,
	assets: ActivityConfigAssets?,
}

export type PresenceManager = {
	getActivity: () -> ActivityConfig?,
	getIsActive: () -> boolean,
	getDisabledAccountIds: () -> { [string]: true },

	setActivity: (ActivityConfig?) -> (),
	setIsActive: (boolean) -> (),
	setAccountActive: (accountId: string, isActive: boolean) -> (),

	destroy: () -> (),
}

--- Convert ActivityConfig into the API format (mostly changing to snake_case.)
local function serializeActivity(activity: ActivityConfig, startedAt: number?): ApiActivity
	local apiActivity: ApiActivity = {
		type = 0, -- PLAYING
		name = activity.name,

		details = activity.details,
		details_url = activity.detailsUrl,

		state = activity.state,
		state_url = activity.stateUrl,

		application_id = BuildVars.discord.clientId,
		platform = "desktop",
	}

	if startedAt then
		apiActivity.timestamps = {
			-- Convert to milliseconds
			start = tostring(startedAt * 1000),
		}
	end

	if activity.assets then
		apiActivity.assets = {
			large_image = activity.assets.largeImage,
			large_text = activity.assets.largeText,
			small_image = activity.assets.smallImage,
			small_text = activity.assets.smallText,
		}
	end

	return apiActivity
end

local function createPresenceManager(discord: DiscordApi.DiscordApi): PresenceManager
	local auth = AuthStore.get()
	local localStorage = LocalStorageStore.get()

	local getActivity, setActivity = signal(nil :: ActivityConfig?)

	local getIsActive = computed(function(): boolean
		local active = localStorage.getStorage().isPresenceActive
		if active == nil then
			return true
		end
		return active
	end)

	local function setIsActive(value: boolean)
		localStorage.setStorage(function(prev)
			local new = table.clone(prev)
			new.isPresenceActive = value
			return new
		end)
	end

	local getDisabledAccountIds = computed(function(): { [string]: true }
		return localStorage.getStorage().disabledAccountIds or {}
	end)

	local function setAccountActive(accountId: string, isActive: boolean)
		localStorage.setStorage(function(prev)
			local new = table.clone(prev)
			local disabled: { [string]: true } = table.clone(prev.disabledAccountIds or {})

			if isActive then
				disabled[accountId] = nil
			else
				disabled[accountId] = true
			end

			new.disabledAccountIds = disabled
			return new
		end)
	end

	-- In-memory session tokens: accountId → sessionToken
	local sessionTokens: { [string]: string } = {}

	-- Tracks when sessions first became active, used as the Discord timestamp.
	local sessionStartedAt: number? = os.time()

	-- Incremented on every sync to detect stale heartbeat writes.
	-- The heartbeat checks this before and after API calls to avoid writing
	-- tokens that were invalidated by a concurrent sync.
	local syncGeneration: number = 0

	-- Tracks when we're next allowed to make Discord API calls.
	-- 0 means no cooldown is active. Value is os.clock()-based (monotonic).
	local apiCooldownUntil: number = 0

	local function waitForCooldownAsync()
		local remaining = apiCooldownUntil - os.clock()
		if remaining > 0 then
			Logger:Info(`PresenceManager: waiting {string.format("%.1f", remaining)}s for API cooldown`)
			task.wait(remaining)
		end
	end

	local function updateCooldown(retryAfterSeconds: number)
		local newUntil = os.clock() + retryAfterSeconds
		apiCooldownUntil = math.max(apiCooldownUntil, newUntil)
	end

	--[[
		Retry an async callback with exponential backoff.
		Returns immediately on success or on non-retryable errors (unauthorized).
		Retries on network, unexpected, and application_not_cached errors.
		Rate-limited errors update the global cooldown and retry after it elapses.
	]]
	local function retryAsync<T, E>(
		callback: () -> { ok: true, value: T } | { ok: false, error: E },
		context: string
	): { ok: true, value: T } | { ok: false, error: E }
		local backoffConfig = RetryBackoff.defaultConfig()
		local backoffState = RetryBackoff.createState()

		for attempt = 1, MAX_RETRIES do
			waitForCooldownAsync()

			local result = callback()

			if result.ok then
				return result
			end

			local err = result.error :: any
			local errorType: string = err.type

			-- Don't retry unauthorized errors — needs auth refresh from external system
			if errorType == "unauthorized" then
				Logger:Warn(`{context}: unauthorized (attempt {attempt}/{MAX_RETRIES})`)
				NotificationStore.get().push("error", "Discord session expired — re-link your account")
				return result
			end

			-- On last attempt, don't wait — just return the error
			if attempt == MAX_RETRIES then
				Logger:Warn(`{context}: failed after {MAX_RETRIES} attempts, last error: {errorType}`)
				NotificationStore.get().push("error", "Failed to update Discord presence")
				return result
			end

			-- Rate limited: update global cooldown, next iteration waits via waitForCooldownAsync
			if errorType == "rate_limited" then
				local retryAfter: number = err.retryAfter or 5
				updateCooldown(retryAfter)
				Logger:Warn(
					`{context}: rate limited (retry_after={string.format("%.1f", retryAfter)}s), attempt {attempt}/{MAX_RETRIES}`
				)
				continue
			end

			-- Calculate delay with backoff, respecting server-provided retryAfter
			local serverRetryAfter: number? = nil
			if errorType == "application_not_cached" then
				local retryAfterMs: number? = err.retryAfter
				if retryAfterMs then
					serverRetryAfter = retryAfterMs / 1000
				end
			end

			local delay = RetryBackoff.nextAttempt(backoffConfig, backoffState, serverRetryAfter)
			Logger:Warn(
				`{context}: {errorType}, retrying in {string.format("%.1f", delay)}s (attempt {attempt}/{MAX_RETRIES})`
			)
			task.wait(delay)
		end

		-- Unreachable, but satisfies the type checker
		return callback()
	end

	--[[
		Check whether an account's access token is nearing expiry and
		refresh it proactively. Returns the (possibly refreshed) access
		token, or nil if the refresh token is also invalid (needs re-auth).
	]]
	local REFRESH_BUFFER_SECONDS = 3600

	local function refreshIfNeededAsync(accountId: string, account: AuthStore.Account): string?
		if os.time() < account.expiresAt - REFRESH_BUFFER_SECONDS then
			return account.accessToken
		end

		if account.refreshToken == "" then
			Logger:Warn(`Cannot refresh token for account {accountId} — no refresh token stored`)
			return account.accessToken
		end

		Logger:Info(`Refreshing access token for account {accountId}`)
		local result = discord.refreshTokenAsync(account.refreshToken)

		if result.ok then
			local newToken = result.value
			auth.setStorage(function(prev)
				local new = table.clone(prev)
				new.accounts = table.clone(prev.accounts)
				new.accounts[accountId] = {
					accessToken = newToken.accessToken,
					refreshToken = newToken.refreshToken or account.refreshToken,
					expiresAt = newToken.expiresAt,
				}
				return new
			end)
			return newToken.accessToken
		end

		local err = result.error
		if err.type == "invalid_grant" then
			Logger:Warn(`Refresh token invalid for account {accountId} — user needs to re-link`)
			NotificationStore.get().push("error", "Discord session expired — re-link your account")
			return nil
		end

		Logger:Warn(`Failed to refresh token for account {accountId}: {err.type}`)
		return account.accessToken
	end

	--[[
		Delete a single session with retry. Clears the session token immediately
		so it's cleaned up even if the API call ultimately fails.
	]]
	local function deleteSessionAsync(accountId: string, accessToken: string, sessionToken: string)
		sessionTokens[accountId] = nil

		retryAsync(function()
			return discord.deleteHeadlessSessionAsync(accessToken, sessionToken)
		end, `PresenceManager: delete session for account {accountId}`)
	end

	--[[
		Delete all active sessions and clear the token table.
	]]
	local function deleteAllSessionsAsync(accounts: { [string]: AuthStore.Account })
		-- Snapshot before clearing so we can still iterate
		local toDelete = table.clone(sessionTokens)
		table.clear(sessionTokens)

		for id, token in toDelete do
			local account = accounts[id]
			if account then
				deleteSessionAsync(id, account.accessToken, token)
			end
		end
	end

	--[[
		Synchronize headless sessions with the current desired state.
		Creates, updates, or deletes sessions as needed.
	]]
	local function syncSessionsAsync(
		accounts: { [string]: AuthStore.Account },
		activity: ActivityConfig?,
		isActive: boolean
	)
		Logger:Info("Syncing presence sessions", {
			activity = activity,
		})

		-- If inactive or no activity, tear down all sessions
		if not isActive or activity == nil then
			deleteAllSessionsAsync(accounts)
			return
		end

		if sessionStartedAt == nil then
			sessionStartedAt = os.time()
		end

		local serialized = serializeActivity(activity, sessionStartedAt)
		local activeAccountIds: { [string]: true } = {}

		for id, account in accounts do
			activeAccountIds[id] = true

			local accessToken = refreshIfNeededAsync(id, account)
			if not accessToken then
				continue
			end

			local existingToken = sessionTokens[id]

			if existingToken then
				local result = retryAsync(function()
					return discord.updateHeadlessSessionAsync(accessToken, existingToken, serialized)
				end, `PresenceManager: update session for account {id}`)

				if result.ok then
					sessionTokens[id] = result.value.sessionToken
				else
					sessionTokens[id] = nil

					local err = result.error
					if err.type == "unauthorized" then
						Logger:Warn(`PresenceManager: auth token expired for account {id}, skipping session create`)
						NotificationStore.get().push("error", "Discord session expired — re-link your account")
					else
						Logger:Warn(
							`PresenceManager: update failed for account {id} ({err.type}), attempting new session`
						)

						local createResult = retryAsync(function()
							return discord.createHeadlessSessionAsync(accessToken, serialized)
						end, `PresenceManager: create session for account {id}`)

						if createResult.ok then
							sessionTokens[id] = createResult.value.sessionToken
						end
					end
				end
			else
				local result = retryAsync(function()
					return discord.createHeadlessSessionAsync(accessToken, serialized)
				end, `PresenceManager: create session for account {id}`)

				if result.ok then
					sessionTokens[id] = result.value.sessionToken
				end
			end
		end

		-- Prune sessions for accounts that were removed.
		-- The account is no longer in auth so we can't make API calls to delete —
		-- the session will expire on its own after 20 minutes.
		for id in sessionTokens do
			if not activeAccountIds[id] then
				Logger:Warn(`PresenceManager: account {id} removed, session will expire naturally`)
				sessionTokens[id] = nil
			end
		end
	end

	--[[
		Session management effect.
		Reacts to changes in auth accounts, activity config, and active state.
		Cancels any in-flight sync when dependencies change.
	]]
	local sessionThread: thread?
	local disposeSessionEffect = effect(function()
		-- Read signals synchronously to register Charm dependencies
		local authAccounts = auth.getStorage().accounts
		local activity = getActivity()
		local isActive = getIsActive()
		local disabledIds = getDisabledAccountIds()

		-- Cancel any in-flight sync from a previous run
		if sessionThread then
			pcall(task.cancel, sessionThread)
		end

		sessionThread = task.delay(SYNC_DEBOUNCE_SECONDS, function()
			syncGeneration += 1

			-- Split accounts into active and disabled sets
			local activeAccounts: { [string]: AuthStore.Account } = {}
			for id, account in authAccounts do
				if not disabledIds[id] then
					activeAccounts[id] = account
				end
			end

			-- Delete sessions for newly-disabled accounts
			for id in disabledIds do
				local token = sessionTokens[id]
				local account = authAccounts[id]
				if token and account then
					deleteSessionAsync(id, account.accessToken, token)
				end
			end

			-- Prune disabled IDs for accounts that no longer exist
			local needsPrune = false
			for id in disabledIds do
				if not authAccounts[id] then
					needsPrune = true
					break
				end
			end
			if needsPrune then
				localStorage.setStorage(function(prev)
					local new = table.clone(prev)
					local cleaned: { [string]: true } = table.clone(prev.disabledAccountIds or {})
					for id in cleaned do
						if not authAccounts[id] then
							cleaned[id] = nil
						end
					end
					new.disabledAccountIds = cleaned
					return new
				end)
			end

			syncSessionsAsync(activeAccounts, activity, isActive)
			sessionThread = nil
		end)
	end)

	--[[
		Heartbeat loop. Runs independently of the reactive effect on a fixed
		interval to keep sessions alive. Uses peek() to avoid registering
		Charm dependencies.
	]]
	local heartbeatThread: thread? = task.spawn(function()
		while true do
			task.wait(HEARTBEAT_INTERVAL)

			local isActive = peek(getIsActive)
			local activity = peek(getActivity)
			if not isActive or activity == nil then
				continue
			end

			local generationBefore = syncGeneration
			local serialized = serializeActivity(activity, sessionStartedAt)
			local authAccounts = peek(auth.getStorage).accounts
			local disabledIds = peek(getDisabledAccountIds)

			-- Snapshot tokens so we iterate a stable set
			local snapshot = table.clone(sessionTokens)

			for id, token in snapshot do
				local account = authAccounts[id]
				if not account or disabledIds[id] then
					continue
				end

				local accessToken = refreshIfNeededAsync(id, account)
				if not accessToken then
					sessionTokens[id] = nil
					continue
				end

				local result = retryAsync(function()
					return discord.updateHeadlessSessionAsync(accessToken, token, serialized)
				end, `PresenceManager: heartbeat for account {id}`)

				-- A sync ran while we were yielding — our data is stale, discard
				if syncGeneration ~= generationBefore then
					break
				end

				if result.ok then
					sessionTokens[id] = result.value.sessionToken
				else
					local err = result.error
					if err.type == "unauthorized" then
						Logger:Warn(`PresenceManager: auth token expired for account {id}, removing session`)
						NotificationStore.get().push("error", "Discord session expired — re-link your account")
						sessionTokens[id] = nil
					end
				end
			end
		end
	end)

	local function destroy()
		disposeSessionEffect()

		if sessionThread then
			pcall(task.cancel, sessionThread)
			sessionThread = nil
		end
		if heartbeatThread then
			pcall(task.cancel, heartbeatThread :: thread)
			heartbeatThread = nil
		end

		-- Fire-and-forget delete all active sessions
		local authAccounts = peek(auth.getStorage).accounts
		for id, token in sessionTokens do
			local account = authAccounts[id]
			if account then
				task.spawn(deleteSessionAsync, id, account.accessToken, token)
			end
		end
		table.clear(sessionTokens)
	end

	return {
		getActivity = getActivity,
		getIsActive = getIsActive,
		getDisabledAccountIds = getDisabledAccountIds,

		setActivity = setActivity,
		setIsActive = setIsActive,
		setAccountActive = setAccountActive,

		destroy = destroy,
	}
end

return createPresenceManager
