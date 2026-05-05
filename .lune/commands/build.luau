--[[
	Build Command

	Builds the plugin to a production .rbxm file with production flags set.
]]

local codegen = require("./codegen")
local color = require("../utils/color")
local errors = require("../lib/cli/errors")
local rojo = require("../lib/project/rojo")

local build = {}

-- Metadata for help command
build.name = "build"
build.description = "Builds the plugin to a production .rbxm"
build.usage = "lune run build [--output <path>]"

-- Argument definitions for CLI parsing
build.arguments = {
	{
		name = "output",
		kind = "option",
		options = {
			help = "Output file path (default: StudioActivity.rbxm)",
			aliases = { "o" },
		},
	},
	{
		name = "release",
		kind = "flag",
		options = {
			help = "Is this a release build? (default: false)",
			aliases = { "r" },
		},
	},
}

export type Options = {
	output: string?,
	release: boolean?,
}

--[[
	Builds the plugin for production.

	@param options Configuration options
]]
function build.run(options_: Options?)
	local options: Options = options_ or {}
	local output = options.output or "StudioActivity.rbxm"
	local release = if options.release ~= nil then options.release else false

	print(color.bold(color.white("Building for production...\n")))

	local codegenSuccess = codegen.run({
		quiet = false,
		production = true,
	})
	if not codegenSuccess then
		return
	end

	print()

	local projectFile = if release then "release.project.json" else "default.project.json"
	local buildResult = rojo.build({
		projectFile = `plugin/{projectFile}`,
		output = output,
		stdio = "inherit",
	})

	if not buildResult.ok then
		errors.processError(
			`Rojo exited with code {buildResult.code} while building`,
			buildResult.code,
			buildResult.stderr
		)
		return
	end

	print()
	print(color.bold(color.green(`Built {output}`)))
end

return build
