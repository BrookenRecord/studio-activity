local fs = require("@lune/fs")
local serde = require("@lune/serde")

local env = require("./env")

local BuildVarsModule = require("../../plugin/src/BuildVars/Types")
type BuildVars = BuildVarsModule.BuildVars

local OUTPUT_PATH = "plugin/src/BuildVars/BuildVars.json"

type Config = {
	production: boolean,
}

local function injectBuildVars(config: Config)
	local isProd = config.production

	local clientId =
		assert(env.loadEnvVar("DISCORD_CLIENT_ID"), "No `DISCORD_CLIENT_ID` provided in environment variables")

	local vars: BuildVars = {
		build = {
			version = "0.0.1",
			channel = "live",
			hash = "blah",
		},

		api = {
			secure = isProd,
			host = if isProd then "presence.brooke.sh" else "localhost:8787",
		},

		discord = {
			clientId = clientId,
		},
	}

	local contents = serde.encode("json", vars, true)
	fs.writeFile(OUTPUT_PATH, contents)
end

return injectBuildVars
