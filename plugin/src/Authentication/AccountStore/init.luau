local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local createAccountStore = require(script.createAccountStore)

return table.freeze({
	get = Charm.computed(function()
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})

		return createAccountStore(discord)
	end),
})
