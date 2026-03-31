--[[
	Patch Command

	Creates or updates a git-format patch for a Wally package.
	Uses a two-phase workflow:
	  1. First run: Snapshots the clean package state (git init + commit)
	  2. Second run: Generates the patch from your changes and cleans up
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local color = require("../utils/color")

local patch = {}

-- Metadata for help command
patch.name = "patch"
patch.description = "Creates or updates a patch for a Wally package"
patch.usage = "lune run patch <package-path>"

-- Argument definitions for CLI parsing
patch.arguments = {
	{
		name = "package-path",
		kind = "positional",
		options = {
			help = "Path to the package directory in Packages/_Index/",
			required = true,
		},
	},
}

local PATCHES_DIR = "plugin/patches"
local PACKAGES_INDEX = "Packages/_Index/"

export type Options = {
	packagePath: string,
}

--[[
	Extracts the package directory name from a path.
	e.g. "plugin/Packages/_Index/jsdotlua_jest@3.10.0" -> "jsdotlua_jest@3.10.0"
	     "plugin/Packages/_Index/jsdotlua_jest@3.10.0/" -> "jsdotlua_jest@3.10.0"
]]
local function getPackageDirName(packagePath: string): string
	-- Remove trailing slash if present
	local cleaned = packagePath:gsub("/$", "")
	-- Get the last path component
	local parts = cleaned:split("/")
	return parts[#parts]
end

--[[
	Validates that the given path is inside Packages/_Index/.
]]
local function isValidPackagePath(packagePath: string): boolean
	return packagePath:find(PACKAGES_INDEX, 1, true) ~= nil
end

--[[
	Phase 1: Prepare a package for patching by snapshotting its clean state.
]]
local function setupForPatching(packagePath: string): boolean
	print(color.dim("Initializing package for patching..."))

	local initResult = process.exec("git", { "init" }, { cwd = packagePath })
	if not initResult.ok then
		print(color.bold(color.red("Failed to initialize git repo")))
		print(color.red(initResult.stderr))
		return false
	end

	local addResult = process.exec("git", { "add", "-A" }, { cwd = packagePath })
	if not addResult.ok then
		print(color.bold(color.red("Failed to stage files")))
		print(color.red(addResult.stderr))
		return false
	end

	local commitResult = process.exec("git", { "commit", "-m", "original" }, { cwd = packagePath })
	if not commitResult.ok then
		print(color.bold(color.red("Failed to commit original state")))
		print(color.red(commitResult.stderr))
		return false
	end

	print()
	print(color.bold(color.green("Package prepared for patching!")))
	print(color.dim("Make your changes to the package, then run this command again to generate the patch."))

	return true
end

--[[
	Phase 2: Generate a patch from changes and clean up.
]]
local function generatePatch(packagePath: string, packageDirName: string): boolean
	print(color.dim("Generating patch..."))

	-- Stage all changes (including new/deleted files)
	local addResult = process.exec("git", { "add", "-A" }, { cwd = packagePath })
	if not addResult.ok then
		print(color.bold(color.red("Failed to stage changes")))
		print(color.red(addResult.stderr))
		return false
	end

	-- Generate the diff
	local diffResult = process.exec("git", { "diff", "--cached" }, { cwd = packagePath })
	if not diffResult.ok then
		print(color.bold(color.red("Failed to generate diff")))
		print(color.red(diffResult.stderr))
		return false
	end

	local diff = diffResult.stdout

	-- Clean up the git repo before potentially returning early
	fs.removeDir(`{packagePath}/.git`)

	if diff == "" or diff == "\n" then
		print(color.yellow("No changes detected. Nothing to patch."))
		return true
	end

	-- Ensure patches directory exists
	if not fs.isDir(PATCHES_DIR) then
		fs.writeDir(PATCHES_DIR)
	end

	-- Write the patch file
	local patchFilePath = `{PATCHES_DIR}/{packageDirName}.patch`
	fs.writeFile(patchFilePath, diff)

	print()
	print(color.bold(color.green("Patch created successfully!")))
	print(color.dim(`  {patchFilePath}`))
	print()
	print(color.dim("Run 'lune run install' to verify the patch applies cleanly."))

	return true
end

--[[
	Creates or updates a patch for a Wally package.

	@param options Configuration options
	@return True if successful, false otherwise
]]
function patch.run(options: Options): boolean
	local packagePath = options.packagePath

	if not fs.isDir(packagePath) then
		print(color.bold(color.red(`Package directory not found: {packagePath}`)))
		return false
	end

	if not isValidPackagePath(packagePath) then
		print(color.bold(color.red("Path must be inside Packages/_Index/")))
		return false
	end

	local packageDirName = getPackageDirName(packagePath)

	-- Detect which phase we're in
	local hasGit = fs.isDir(`{packagePath}/.git`)

	if hasGit then
		return generatePatch(packagePath, packageDirName)
	else
		return setupForPatching(packagePath)
	end
end

return patch
