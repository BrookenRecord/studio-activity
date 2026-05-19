local Plugin = script:FindFirstAncestor("StudioActivity")

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local createPresenceManager = require(script.createPresenceManager)
local createSingleton = require(Plugin.Source.Common.createSingleton)

export type PresenceManager = createPresenceManager.PresenceManager
export type ActivityConfig = createPresenceManager.ActivityConfig
export type ActivityConfigAssets = createPresenceManager.ActivityConfigAssets

return table.freeze({
	get = createSingleton(function()
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})

		return createPresenceManager(discord)
	end),
})
