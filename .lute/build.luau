local cli = require("@batteries/cli")
local dotenv = require("@dotenv")
local fs = require("@std/fs")
local path = require("@std/path")
local pp = require("@batteries/pp")
local process = require("@std/process")
local richterm = require("@batteries/richterm")
local toml = require("@batteries/toml")

local buildSystem = require("@scripts/lib/build-system")
local copyInto = require("@scripts/lib/copyInto")
local getStudioPluginsPath = require("@scripts/lib/getStudioPluginsPath")
local project = require("@repo/project")
local run = require("@scripts/lib/run")
local watch = require("@scripts/lib/watch")

local WALLY_MANIFEST_PATH = path.resolve("plugin/wally.toml")
local PROD_API_HOST = "activity.brooke.sh"

type BuildContext = buildSystem.BuildContext

pcall(dotenv.config)

local args = cli.parser()

args:add("channel", "option", {
	help = "Channel to build for",
	aliases = { "c" },
	default = "prod",
})
args:add("target", "option", {
	help = "Target to build for",
	aliases = { "t" },
	default = "local",
})
args:add("output", "option", {
	help = "Full path to the rbxm file to build",
	aliases = { "o" },
	default = tostring(path.join(getStudioPluginsPath(), project.PLUGIN_FILENAME)),
})
args:add("watch", "flag", {
	help = "Watch for changes and recompile automatically",
	aliases = { "w" },
})
args:add("skip-reload", "flag", {
	help = "Skip reloading the plugin in Roblox Studio",
})
args:add("clean", "flag", {
	help = "Performs a full rebuild of the project",
})

args:parse({ ... })

local channel = args:get("channel")
assert(channel == "dev" or channel == "prod", `bad value for channel (must be one of "dev" or "prod", got "{channel}")`)

local target = args:get("target")
assert(
	target == "creator-store" or target == "local",
	`bad value for target (must be one of "creator-store" or "local", got "{target}")`
)

local output = args:get("output")
assert(typeof(output) == "string", `bad value for output (string expected, got {typeof(output)})`)

local function readWallyManifestAsync()
	return toml.deserialize(fs.readFileToString(WALLY_MANIFEST_PATH))
end

local function getCommitHash()
	local commitHash = run("git", { "rev-parse", "--short", "HEAD" }, {
		captureOutput = true,
	})
	assert(commitHash ~= nil and commitHash ~= "", "commit hash is empty")
	return commitHash
end

local function fail(message: string): never
	error(`[release preflight] {message}`, 0)
end

local function assertReleaseContext(context: BuildContext)
	if context.channel ~= "prod" then
		return
	end

	if context.target ~= "creator-store" then
		fail(`prod builds must target creator-store, got "{context.target}"`)
	end

	if context.vars.api.host ~= PROD_API_HOST then
		fail(`prod builds must use API_HOST={PROD_API_HOST}, got "{context.vars.api.host}"`)
	end

	if context.vars.api.secure ~= true then
		fail("prod builds must use secure API requests")
	end

	if context.vars.build.isDev ~= false then
		fail("prod builds must set BuildVars.build.isDev=false")
	end

	local clientId = context.vars.discord.clientId
	if clientId == nil or clientId == "" or clientId == "MISSING_CLIENT_ID" then
		fail("DISCORD_CLIENT_ID must be set for prod builds")
	end
end

local function assertReleaseTree(context: BuildContext)
	if context.channel ~= "prod" then
		return
	end

	local forbidden = {}

	for _, dir in project.PROD_CONFIG.prunedDirs do
		local relativePath = path.relative(project.PLUGIN_PATH, dir)
		local buildPath = path.join(context.dest, relativePath)
		if fs.exists(buildPath) then
			table.insert(forbidden, tostring(buildPath))
		end
	end

	for _, pattern in project.PROD_CONFIG.prunedFiles do
		local matches = run("find", { context.dest, "-type", "f", "-name", `"{pattern}"`, "-print" }, {
			captureOutput = true,
		})
		if matches ~= nil and matches ~= "" then
			for line in matches:gmatch("[^\n]+") do
				table.insert(forbidden, line)
			end
		end
	end

	if #forbidden > 0 then
		fail(`prod build contains forbidden files:\n{table.concat(forbidden, "\n")}`)
	end
end

-- This environment variable comes from `.env` and is required to be set. This
-- condition just makes sure if it's _not_ set that the user will then go and
-- get their `.env` file in order
if not process.env.API_HOST then
	error(table.concat({
		"One or more critical environment variables are not set.",
		"Please make sure to copy `.env.template` to `.env`. If you already have a `.env` file, make sure the environment variables from the template match your local copy",
	}, "\n\n"))
end

local context: BuildContext = {
	channel = channel,
	target = target,
	shouldRebuild = args:has("clean"),
	dest = path.join(project.BUILD_PATH, channel, target),
	vars = {
		build = {
			version = (readWallyManifestAsync() :: any).package.version,
			channel = channel,
			target = target,
			isDev = channel ~= "prod",
			hash = getCommitHash(),
		},

		api = {
			secure = channel == "prod",
			host = if channel == "prod" then process.env.API_HOST else "localhost:8787",
		},

		discord = {
			clientId = process.env.DISCORD_CLIENT_ID,
		},
	},
	cache = buildSystem.readBuildCacheAsync(),
}

assertReleaseContext(context)

local function buildPluginBinary()
	buildSystem.runBuildGroupAsync({
		name = "🔌 plugin binary",
		paths = { context.dest },
		context = context,
		step = function()
			local projectPath = path.resolve(path.join(context.dest, "default.project.json"))
			copyInto(project.ROJO_BUILD_PROJECT, projectPath)

			local dest = path.resolve(path.join(context.dest, "..", project.PLUGIN_FILENAME))

			run("rojo", {
				"build",
				projectPath,
				"-o",
				dest,
			})

			fs.remove(projectPath)

			if args:has("skip-reload") then
				if output:match(tostring(getStudioPluginsPath())) then
					return
				end
			end

			copyInto(dest, output)
		end,
	})
end

local function build()
	local startTime = os.clock()

	local contextNoCache = table.clone(context)
	contextNoCache.cache = nil :: any
	print(richterm.dim(`build context: {pp(contextNoCache)}`))

	buildSystem.compileAsync(context)
	assertReleaseTree(context)
	buildSystem.writeBuildCacheAsync(context.cache)

	buildPluginBinary()

	print(`build completed in {("%.2f"):format(os.clock() - startTime)}s`)
end

build()

if args:has("watch") then
	local function onChanged(filePath: path.Path)
		print("change?", filePath)
		if tostring(filePath):match(tostring(project.PLUGIN_PATH)) then
			buildSystem.writeBuildCacheAsync(context.cache)
			buildPluginBinary()
		else
			build()
		end
	end

	watch({
		roots = {
			"./plugin",
			"./protos",
		},
		excludedFilePatterns = {
			".*Packages",
			"build",
		},
		onChanged = onChanged,
	})
end
