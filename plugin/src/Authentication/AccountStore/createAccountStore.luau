local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local signal = Charm.signal

local DiscordApi = require(Plugin.Source.Api.Discord)
type User = DiscordApi.User
type AvatarImage = DiscordApi.AvatarImage

local AuthStore = require(script.Parent.Parent.AuthStore)

export type AccountStore = {
	cachedUsers: () -> { User },
	cachedUserImages: () -> { [string]: AvatarImage },

	addUser: (account: AuthStore.Account) -> (),
	removeUser: (id: string) -> (),
}

local function createAccountStore(): AccountStore
	local getCachedUsers, setCachedUsers = signal<<{ User }>>({})
	local cachedUserImages, setCachedUserImages = signal<<{ [string]: AvatarImage }>>({})

	local function addUser(account: AuthStore.Account) end

	return {}
end

return createAccountStore
