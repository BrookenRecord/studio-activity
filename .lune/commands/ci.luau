--[[
	CI Command

	Runs static analysis checks: linting (Selene), formatting (StyLua),
	and type checking (luau-lsp).
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local codegen = require("./codegen")
local color = require("../utils/color")

local ci = {}

-- Metadata for help command
ci.name = "ci"
ci.description = "Runs static analysis (lint, format check, type check)"
ci.usage = "lune run ci [--fix]"

-- Argument definitions for CLI parsing
ci.arguments = {
	{
		name = "fix",
		kind = "flag",
		options = {
			help = "Auto-fix formatting issues instead of just checking",
			aliases = { "f" },
		},
	},
}

export type Options = {
	fix: boolean?,
}

-- Paths to analyze
local ANALYZE_PATHS = { ".lune", "plugin/bin", "plugin/src" }

-- Patterns to ignore in luau-lsp
local IGNORE_PATTERNS = { "plugin/Packages/**" }

--[[
	Runs a command and returns whether it succeeded.

	@param program The program to run
	@param args The arguments to pass
	@param description A description for the step
	@return True if successful, false otherwise
]]
local function runStep(program: string, args: { string }, description: string): boolean
	print(color.cyan(`→ {description}`))

	local result = process.exec(program, args, {
		stdio = "inherit",
		shell = true,
	})

	if result.ok then
		print(color.green(`  ✓ {description} passed`))
		return true
	else
		print(color.red(`  ✗ {description} failed`))
		return false
	end
end

--[[
	Downloads the global Luau types file if it doesn't exist.

	@return True if successful, false otherwise
]]
local function fetchGlobalTypes(): boolean
	local typesFile = "plugin/generated/globalTypes.d.luau"

	if not fs.isDir("plugin/generated") then
		fs.writeDir("plugin/generated")
	end

	if fs.isFile(typesFile) then
		print(color.dim(`  Skipping download, {typesFile} already exists`))
		return true
	end

	print(color.cyan("→ Fetching Luau global types"))

	local response = net.request({
		url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.luau",
		method = "GET",
	})

	if not response.ok then
		print(color.red(`  ✗ Failed to fetch global types: {response.statusCode}`))
		return false
	end

	fs.writeFile(typesFile, response.body)
	print(color.green(`  ✓ Downloaded {typesFile}`))
	return true
end

--[[
	Runs all CI checks.

	@param options Configuration options
	@return True if all checks pass, false otherwise
]]
function ci.run(options_: Options?): boolean
	local options: Options = options_ or {}
	local fix = if options.fix ~= nil then options.fix else false

	print(color.bold(color.white("Running static analysis...\n")))

	local allPassed = true

	-- Step 1: Lint check (Selene)
	local seleneArgs = table.clone(ANALYZE_PATHS)
	if not runStep("selene", seleneArgs, "Lint check (Selene)") then
		allPassed = false
	end
	print()

	-- Step 2: Style check (StyLua)
	local styluaArgs = {}
	if not fix then
		table.insert(styluaArgs, "-c")
	end
	for _, path in ANALYZE_PATHS do
		table.insert(styluaArgs, path)
	end

	local styluaDesc = if fix then "Format (StyLua --fix)" else "Style check (StyLua)"
	if not runStep("stylua", styluaArgs, styluaDesc) then
		allPassed = false
	end
	print()

	-- Step 3: Fetch global types
	if not fetchGlobalTypes() then
		allPassed = false
	end
	print()

	-- Step 4: Update sourcemap
	print(color.cyan("→ Updating sourcemap"))
	local codegenSuccess = codegen.run({ quiet = true, generateSourcemap = true })
	if codegenSuccess then
		print(color.green("  ✓ Sourcemap updated"))
	else
		print(color.red("  ✗ Failed to update sourcemap"))
		allPassed = false
	end
	print()

	-- Step 5: Type check (luau-lsp)
	local luauArgs = {
		"analyze",
		"--sourcemap",
		"plugin/generated/sourcemap.json",
		"--platform",
		"roblox",
		"--definitions",
		"plugin/generated/globalTypes.d.luau",
		"--settings",
		".vscode/settings.json",
	}

	for _, pattern in IGNORE_PATTERNS do
		table.insert(luauArgs, `--ignore={pattern}`)
	end

	for _, path in ANALYZE_PATHS do
		table.insert(luauArgs, path)
	end

	if not runStep("luau-lsp", luauArgs, "Type check (luau-lsp)") then
		allPassed = false
	end
	print()

	-- Summary
	if allPassed then
		print(color.bold(color.green("All checks passed!")))
	else
		print(color.bold(color.red("Some checks failed.")))
		process.exit(1)
	end

	return allPassed
end

return ci
