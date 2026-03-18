--[[
	Codegen Command

	Runs all code generation tasks: compiles networking, generates project links,
	and generates the sourcemap.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local color = require("../utils/color")
local injectBuildVars = require("../utils/inject-build-vars")
local rojo = require("../lib/project/rojo")

local codegen = {}

-- Metadata for help command
codegen.name = "codegen"
codegen.description = "Runs all code generation (sourcemap only for now)"
codegen.usage = "lune run codegen"

-- Argument definitions for CLI parsing
codegen.arguments = {
	{
		name = "protos",
		kind = "flag",
		options = {
			help = "Generate protobuf files",
		},
	},
}

export type Options = {
	quiet: boolean?,
	production: boolean?,
	generateSourcemap: boolean?,
	generateProtos: boolean?,
}

--[[
	Runs all code generation tasks.

	@param options Configuration options
	@return True if successful, false otherwise
]]
function codegen.run(options_: Options?): boolean
	local options: Options = options_ or {}
	local quiet = if options.quiet ~= nil then options.quiet else false
	local production = if options.production ~= nil then options.production else false

	injectBuildVars({
		production = production,
	})

	if options.generateSourcemap then
		if not fs.isDir("plugin/generated") then
			fs.writeDir("plugin/generated")
		end

		-- Generate sourcemap
		local sourcemapSuccess, sourcemapError = rojo.sourcemap({
			projectFile = "plugin/default.project.jsonc",
			output = "plugin/generated/sourcemap.json",
			absolute = true,
		})
		if not sourcemapSuccess then
			if not quiet then
				print(color.bold(color.red("Failed to generate sourcemap")))
				print(sourcemapError)
			end
			return false
		end

		if not quiet then
			print(color.bold(color.dim("Sourcemap generated successfully!")))
		end
	end

	if options.generateProtos then
		local result = process.exec("npm", {
			"run",
			"proto:generate",
		}, {
			cwd = "backend",
		})

		if not result.ok then
			if not quiet then
				print(color.bold(color.red("Failed to generate protos")))
				print(result.stderr)
			end
			return false
		end

		if not quiet then
			print(color.bold(color.dim("Protos generated successfully!")))
		end
	end

	if not quiet then
		print(color.bold(color.green("Code generation complete!")))
	end

	return true
end

return codegen
