local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local signal = Charm.signal
local effect = Charm.effect
local peek = Charm.peek

local DiscordApi = require(Plugin.Source.Api.Discord)
type ApiUser = DiscordApi.User
type AvatarImage = DiscordApi.AvatarImage

local AuthStore = require(script.Parent.Parent.AuthStore)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)

export type LocalUser =
	| {
		status: "loading",
		cachedDetails: ApiUser?,
	}
	| {
		status: "error",
		problemType: string,
		cachedDetails: ApiUser?,
	}
	| {
		status: "ready",
		details: ApiUser,
	}

-- Tracks the avatar hash that was used to fetch the cached image,
-- so we can invalidate when the user changes their avatar.
type CachedAvatar = {
	image: AvatarImage,
	avatarHash: string?,
}

export type AccountStore = {
	cachedUsers: () -> { [string]: LocalUser },
	cachedUserImages: () -> { [string]: AvatarImage },

	addUserAsync: (account: AuthStore.Account) -> boolean,
	removeUser: (id: string) -> (),
	destroy: () -> (),
}

-- Returns the user details from any LocalUser variant, preferring
-- fresh details over cached ones.
local function getUserDetails(user: LocalUser): ApiUser?
	if user.status == "ready" then
		return user.details
	end
	return user.cachedDetails
end

-- Read user details previously persisted to local storage.
local function readDetailsDiskCache(): { [string]: ApiUser }
	local store = peek(LocalStorageStore.get)
	local storage = peek(store.getStorage)
	return storage.userDetailsCache or {}
end

-- Persist user details to local storage so they survive restarts.
local function writeDetailsDiskCache(cache: { [string]: ApiUser })
	local store = peek(LocalStorageStore.get)
	store.setStorage(function(prev)
		local new = table.clone(prev)
		new.userDetailsCache = cache
		return new
	end)
end

local function createAccountStore(discord: DiscordApi.DiscordApi): AccountStore
	local auth = AuthStore.get()

	local getCachedUsers, setCachedUsers = signal<<{ [string]: LocalUser }>>({})
	local getCachedAvatars, setCachedAvatars = signal<<{ [string]: CachedAvatar }>>({})

	-- Public read-only projection that strips the internal avatarHash tracking
	local function getCachedUserImages(): { [string]: AvatarImage }
		local avatars = getCachedAvatars()
		local images: { [string]: AvatarImage } = {}
		for id, cached in avatars do
			images[id] = cached.image
		end
		return images
	end

	--[[
		Cache user details when the underlying auth storage changes.

		The effect synchronously reads `auth.getStorage()` to register
		the charm dependency, then spawns a thread to do the async
		fetches. If the effect re-fires before the thread finishes,
		the previous thread is cancelled.
	]]
	local userDetailsThread: thread?
	local disposeUserDetailsEffect = effect(function()
		local authAccounts = auth.getStorage().accounts

		-- Cancel any in-flight work from a previous run
		if userDetailsThread then
			pcall(task.cancel, userDetailsThread)
		end

		userDetailsThread = task.spawn(function()
			local diskCache = readDetailsDiskCache()

			-- Pre-fill: preserve already-resolved users, set everything else
			-- to loading. Built from scratch so removed accounts are pruned.
			local working: { [string]: LocalUser } = {}
			local currentCache = peek(getCachedUsers)
			for id, _ in authAccounts do
				local existing = currentCache[id]
				if existing and existing.status == "ready" then
					working[id] = existing
				else
					working[id] = { status = "loading", cachedDetails = diskCache[id] }
				end
			end

			setCachedUsers(table.clone(working))

			local diskCacheUpdated = false
			local newDiskCache = table.clone(diskCache)

			-- Fetch any users not already cached
			for id, account in authAccounts do
				if working[id].status == "ready" then
					continue
				end

				local result = discord.getCurrentUserAsync(account.accessToken)
				if result.ok then
					working[id] = {
						status = "ready",
						details = result.value,
					}
					newDiskCache[id] = result.value
					diskCacheUpdated = true
				else
					working[id] = {
						status = "error",
						problemType = result.error.type :: string,
						cachedDetails = diskCache[id],
					}
				end
			end

			-- Prune removed accounts from disk cache
			for id in newDiskCache do
				if not authAccounts[id] then
					newDiskCache[id] = nil
					diskCacheUpdated = true
				end
			end

			setCachedUsers(table.clone(working))

			if diskCacheUpdated then
				writeDetailsDiskCache(newDiskCache)
			end

			userDetailsThread = nil
		end)
	end)

	--[[
		Cache user avatar images when cached users change.

		Same pattern: read the signal synchronously to register the
		dependency, then spawn async work. Compares avatar hashes so
		a changed avatar triggers a re-download.

		Avatars are also resolved for loading/error users that have
		cachedDetails, since the avatar CDN is public and does not
		require authentication.
	]]
	local avatarThread: thread?
	local disposeAvatarEffect = effect(function()
		local cachedUsers = getCachedUsers()

		if avatarThread then
			pcall(task.cancel, avatarThread)
		end

		avatarThread = task.spawn(function()
			local previousAvatars = peek(getCachedAvatars)

			-- Start from a pruned copy: only keep entries for users
			-- that still exist and whose avatar hash hasn't changed.
			local working: { [string]: CachedAvatar } = {}
			for id, user in cachedUsers do
				local details = getUserDetails(user)
				if not details then
					continue
				end

				local existing = previousAvatars[id]
				if existing and existing.avatarHash == details.avatar then
					-- Avatar unchanged, keep the cached image
					working[id] = existing
				end
			end

			-- Download missing or invalidated avatars
			for id, user in cachedUsers do
				local details = getUserDetails(user)
				if not details then
					continue
				end

				if working[id] then
					continue
				end

				local result = discord.getUserAvatarAsync(details)
				if result.ok then
					working[id] = {
						image = result.value,
						avatarHash = details.avatar,
					}
				end

				-- On failure we silently skip — the UI can show a fallback.
				-- The next time the effect runs (e.g. on refresh) it will retry
				-- since there's no entry in `working` for this user.
			end

			setCachedAvatars(table.clone(working))
			avatarThread = nil
		end)
	end)

	local function addUserAsync(account: AuthStore.Account): boolean
		-- This is a duplicate API call but we need to do it to get the user ID.
		-- It's only a duplicate in the adding a new user case.
		local detailsResult = discord.getCurrentUserAsync(account.accessToken)
		if not detailsResult.ok then
			NotificationStore.get().push("error", "Failed to link account")
			return false
		end

		local id = detailsResult.value.id
		auth.setStorage(function(prev)
			local new = table.clone(prev)
			new.accounts = table.clone(prev.accounts)
			new.accounts[id] = account
			return new
		end)

		NotificationStore.get().push("info", `Linked account {detailsResult.value.username}`)
		return true
	end

	local function removeUser(id: string)
		auth.setStorage(function(prev)
			local new = table.clone(prev)
			new.accounts = table.clone(prev.accounts)
			new.accounts[id] = nil
			return new
		end)
	end

	local function destroy()
		disposeUserDetailsEffect()
		disposeAvatarEffect()

		if userDetailsThread then
			pcall(task.cancel, userDetailsThread)
			userDetailsThread = nil
		end

		if avatarThread then
			pcall(task.cancel, avatarThread)
			avatarThread = nil
		end
	end

	return {
		cachedUsers = getCachedUsers,
		cachedUserImages = getCachedUserImages,

		addUserAsync = addUserAsync,
		removeUser = removeUser,
		destroy = destroy,
	}
end

return createAccountStore
