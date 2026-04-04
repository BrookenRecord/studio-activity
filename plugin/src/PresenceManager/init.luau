local Plugin = script:FindFirstAncestor("StudioActivity")

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local createPresenceManager = require(script.createPresenceManager)

export type PresenceManager = createPresenceManager.PresenceManager
export type ActivityConfig = createPresenceManager.ActivityConfig
export type ActivityConfigAssets = createPresenceManager.ActivityConfigAssets

local instance = nil

local function get()
	if not instance then
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})
		instance = createPresenceManager(discord)
	end
	return instance
end

return table.freeze({ get = get })
