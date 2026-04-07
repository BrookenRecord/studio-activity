local fs = require("@lune/fs")
local serde = require("@lune/serde")

local env = require("./env")
local exec = require("../lib/process/exec")

local BuildVarsModule = require("../../plugin/src/BuildVars/Types")
type BuildVars = BuildVarsModule.BuildVars

local OUTPUT_PATH = "plugin/src/BuildVars/BuildVars.json"
local WALLY_TOML_PATH = "plugin/wally.toml"

type Config = {
	production: boolean,
}

local function injectBuildVars(config: Config)
	local isProd = config.production

	local clientId = env.loadEnvVar("DISCORD_CLIENT_ID") :: string
	if not clientId then
		if isProd then
			error("No `DISCORD_CLIENT_ID` provided in environment variables (required for production builds)")
		end
		clientId = "MISSING_CLIENT_ID"
	end

	local gitHash = exec.run("git", { "rev-parse", "--short", "HEAD" }, { quiet = true })

	local wallyToml = serde.decode("toml", fs.readFile(WALLY_TOML_PATH)) :: any
	local version: string = wallyToml.package.version or "0.0.0"

	local vars: BuildVars = {
		build = {
			version = version,
			channel = "live",
			hash = gitHash,
			isDev = not isProd,
		},

		api = {
			secure = isProd,
			host = if isProd then "activity.brooke.sh" else "localhost:8787",
		},

		discord = {
			clientId = clientId,
		},
	}

	local contents = serde.encode("json", vars, true)
	fs.writeFile(OUTPUT_PATH, contents)
end

return injectBuildVars
