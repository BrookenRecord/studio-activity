--[[
	Dev Command

	Starts a development session. Runs codegen, builds the project,
	starts Rojo serve, and optionally opens in Studio.
]]

local process = require("@lune/process")
local task = require("@lune/task")

local codegen = require("./codegen")
local color = require("../utils/color")
local errors = require("../lib/cli/errors")
local rojo = require("../lib/project/rojo")

local dev = {}

-- Metadata for help command
dev.name = "dev"
dev.description = "Starts a development session with Rojo serve"
dev.usage = "lune run dev"

-- Argument definitions for CLI parsing
dev.arguments = {}

export type Options = {}

--[[
	Starts a development session.

	@param options Configuration options
]]
function dev.run(_options: Options)
	print(color.bold(color.white("Setting up development environment...\n")))

	-- Run code generation (but not install - assumes setup was already run)
	local codegenSuccess = codegen.run({ quiet = false })
	if not codegenSuccess then
		return
	end

	print()

	-- Build plugin with Rojo
	task.spawn(function()
		local buildResult = rojo.build({
			projectFile = "plugin/default.project.json",
			plugin = "StudioActivity.rbxm",
			watch = true,
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
	end)

	-- Server backend
	task.spawn(function()
		local result = process.exec("npx", {
			"wrangler",
			"dev",
			"--cwd",
			"backend",
		}, {
			stdio = "inherit",
		})

		if not result.ok then
			errors.processError(`Failed to start backend server`, result.code, result.stderr)
			return
		end
	end)
end

return dev
