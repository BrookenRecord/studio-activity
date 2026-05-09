local cli = require("@batteries/cli")
local dotenv = require("@dotenv")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local project = require("@repo/project")
local run = require("./lib/run")

pcall(dotenv.config)
local args = cli.parser()

args:add("apiKey", "option", {
	help = "Open Cloud API key used for running Luau Execution. Can also be "
		.. "supplied by the ROBLOX_API_KEY environment variable",
	aliases = { "k" },
})

args:add("filter", "option", {
	help = "Specify a filepath pattern to match for when running tests",
})

args:parse({ ... })

local apiKey = process.env.ROBLOX_API_KEY or args:get("apiKey")
if not apiKey then
	error(
		"A valid Open Cloud API key must be supplied with either the --apiKey flag or the ROBLOX_API_KEY environment variable"
	)
end

local filter = args:get("filter")
local testPathPattern = if filter then filter else "__null__"

run("rocale", {
	"run",
	"--script",
	".lute/tasks/run-tests.luau",
	"--load.project",
	tostring(project.ROJO_TESTS_PROJECT),
	"--universeId",
	process.env.ROBLOX_UNIT_TESTING_UNIVERSE_ID,
	"--placeId",
	process.env.ROBLOX_UNIT_TESTING_PLACE_ID,
	"--output",
	tostring(path.join(system.tmpdir(), "tests.rbxl")),
	"--lua.globals",
	`JEST_TEST_PATH_PATTERN={testPathPattern}`,
}, {
	env = {
		ROBLOX_API_KEY = apiKey,
	},
})
