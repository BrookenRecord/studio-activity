local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)
local Logger = require(Plugin.Source.Logger)

type ApplicationAsset = DiscordApi.ApplicationAsset

local CDN_BASE = "https://cdn.discordapp.com"

local function createAppAssetsStore(discord: DiscordApi.DiscordApi)
	local clientId = BuildVars.discord.clientId
	local getAssetsByName, setAssetsByName = Charm.signal({} :: { [string]: ApplicationAsset })

	-- Fetch assets once on creation
	task.spawn(function()
		local result = discord.getApplicationAssetsAsync()
		if not result.ok then
			Logger:Warn("Failed to fetch application assets", {
				errorType = result.error.type,
			})
			return
		end

		local byName: { [string]: ApplicationAsset } = {}
		for _, asset in result.value do
			byName[asset.name] = asset
		end
		setAssetsByName(byName)

		Logger:Info(`Cached {#result.value} application assets`)
	end)

	local function resolveId(nameOrId: string): string
		local assets = getAssetsByName()
		local asset = assets[nameOrId]
		if asset then
			return asset.id
		end
		return nameOrId
	end

	local function resolveUrl(nameOrId: string): string
		if string.sub(nameOrId, 1, 4) == "http" then
			return nameOrId
		end

		local id = resolveId(nameOrId)
		return `{CDN_BASE}/app-assets/{clientId}/{id}.png`
	end

	return {
		getAssetsByName = getAssetsByName,
		resolveId = resolveId,
		resolveUrl = resolveUrl,
	}
end

return {
	get = Charm.computed(function()
		local discord = DiscordApi.new({
			clientId = BuildVars.discord.clientId,
		})

		return createAppAssetsStore(discord)
	end),
}
