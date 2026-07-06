local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local project = require("@repo/project")

local rawArgs = { ... }

local function hasArg(name: string, alias: string?): boolean
	for _, arg in rawArgs do
		if arg == name or (alias ~= nil and arg == alias) then
			return true
		end
	end
	return false
end

local quiet = hasArg("--quiet", "-q")

local function log(message: string)
	if not quiet then
		print(message)
	end
end

local function command(program: string, params: { string }, captureOutput: boolean?): string
	local commandLine = `{program} {table.concat(params, " ")}`
	if not quiet then
		print(`RUN > {commandLine}`)
	end

	local result = process.system(commandLine, {
		stdio = if captureOutput or quiet then "default" else "inherit",
	})

	if not result.ok then
		if result.stderr ~= "" then
			print(result.stderr)
		end
		process.exit(1)
	end

	return result.stdout:gsub("^\n", ""):gsub("\n$", "")
end

local function ensureDir(filePath: string)
	if not fs.exists(filePath) or fs.type(filePath) ~= "dir" then
		fs.createDirectory(filePath, {
			makeParents = true,
		})
	end
end

local function writeBuildVars()
	local wallyToml = fs.readFileToString("plugin/wally.toml")
	local version = wallyToml:match('version%s*=%s*"([^"]+)"') or "0.0.0"
	local clientId = process.env.DISCORD_CLIENT_ID or "MISSING_CLIENT_ID"

	local vars = {
		build = {
			version = version,
			channel = "live",
			target = "",
			hash = command("git", { "rev-parse", "--short", "HEAD" }, true),
			isDev = true,
		},

		api = {
			secure = false,
			host = "localhost:8787",
		},

		discord = {
			clientId = clientId,
		},
	}

	ensureDir(tostring(path.dirname(project.BUILD_VARS_PATH)))
	fs.writeStringToFile(project.BUILD_VARS_PATH, json.serialize(vars, true))
end

log("Setting up project...")
ensureDir("plugin/generated")
writeBuildVars()

local installArgs = { "run", "install" }
if quiet then
	table.insert(installArgs, "--quiet")
end
command("lute", installArgs)

log("Project setup complete!")
