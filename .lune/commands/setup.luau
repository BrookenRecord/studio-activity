--[[
	Setup Command
	
	Sets up the project for development or CI. Runs code generation and installs packages.
]]

local codegen = require("./codegen")
local color = require("../utils/color")
local fs = require("@lune/fs")
local install = require("./install")

local setup = {}

-- Metadata for help command
setup.name = "setup"
setup.description = "Sets up the project (codegen + install packages)"
setup.usage = "lune run setup [--quiet]"

-- Argument definitions for CLI parsing
setup.arguments = {
	{
		name = "quiet",
		kind = "flag",
		options = {
			help = "Suppress output",
			aliases = { "q" },
		},
	},
}

export type Options = {
	quiet: boolean?,
}

--[[
	Sets up the project by running codegen and installing packages.
	
	@param options Configuration options
	@return True if successful, false otherwise
]]
function setup.run(options_: Options?): boolean
	local options: Options = options_ or {}
	local quiet = if options.quiet ~= nil then options.quiet else false

	if not quiet then
		print(color.bold(color.white("Setting up project...\n")))
	end

	if not fs.isDir("plugin/generated") then
		fs.writeDir("plugin/generated")
	end

	-- Run code generation
	local codegenSuccess = codegen.run({
		quiet = quiet,
		-- Generating the sourcemap requires packages to be installed, but we
		-- can't install packages before this step because it requires the
		-- sourcemap project to be generated. So we generate most of the code
		-- now, and generate the sourcemap later.
		generateSourcemap = false,
	})
	if not codegenSuccess then
		return false
	end

	if not quiet then
		print()
	end

	-- Install packages
	local installSuccess = install.run({ quiet = quiet })
	if not installSuccess then
		return false
	end

	-- Generate sourcemap
	codegenSuccess = codegen.run({
		quiet = quiet,
		generateSourcemap = true,
	})
	if not codegenSuccess then
		return false
	end

	if not quiet then
		print()
		print(color.bold(color.green("Project setup complete!")))
	end

	return true
end

return setup
