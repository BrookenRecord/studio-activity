local Plugin = script:FindFirstAncestor("StudioActivity")

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local createAccountStore = require(script.createAccountStore)

local instance = nil

local function get()
	if not instance then
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})
		instance = createAccountStore(discord)
	end
	return instance
end

return table.freeze({ get = get })
