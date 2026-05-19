local Plugin = script:FindFirstAncestor("StudioActivity")

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local createAccountStore = require(script.createAccountStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)

return table.freeze({
	get = createSingleton(function()
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})

		return createAccountStore(discord)
	end),
})
