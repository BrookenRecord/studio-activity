local cli = require("@batteries/cli")
local path = require("@std/path")
local process = require("@std/process")
local run = require("./lib/run")
local system = require("@std/system")

local dotenv = require("@dotenv")
pcall(dotenv.config)

local UNIVERSE_ID = 10128045586
local PLACE_ID = 137718969043315

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

run("rocale", {
	"run",
	"--script",
	".lute/tasks/run-tests.luau",
	"--load.project",
	"plugin/tests.project.json",
	"--universeId",
	UNIVERSE_ID,
	"--placeId",
	PLACE_ID,
	"--output",
	tostring(path.join(system.tmpdir(), "tests.rbxl")),
}, {
	env = {
		ROBLOX_API_KEY = apiKey,
	},
})
