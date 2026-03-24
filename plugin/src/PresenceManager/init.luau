local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local createPresenceManager = require(script.createPresenceManager)

export type PresenceManager = createPresenceManager.PresenceManager
export type ActivityConfig = createPresenceManager.ActivityConfig
export type ActivityConfigAssets = createPresenceManager.ActivityConfigAssets

return table.freeze({
	get = Charm.computed(function()
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})

		return createPresenceManager(discord)
	end),
})
