local cli = require("@batteries/cli")

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

print(args)
