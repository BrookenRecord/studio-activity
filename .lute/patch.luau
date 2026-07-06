local fs = require("@std/fs")
local process = require("@std/process")

local rawArgs = { ... }
if rawArgs[1] == "patch" then
	table.remove(rawArgs, 1)
end

local PATCHES_DIR = "plugin/patches"

local function printUsage()
	print("Usage: lute run patch <package-path>")
	print()
	print("Creates or updates a git-format patch for an installed package.")
	print("Run once to snapshot the clean package, edit the package, then run again to write the patch.")
end

local function fail(message: string)
	print(message)
	process.exit(1)
end

local function command(program: string, params: { string }, options: { cwd: string?, captureOutput: boolean? }?): string
	local result = process.system(`{program} {table.concat(params, " ")}`, {
		stdio = if options ~= nil and options.captureOutput then "default" else "inherit",
		cwd = if options then options.cwd else nil,
	})

	if not result.ok then
		if result.stderr ~= "" then
			print(result.stderr)
		end
		process.exit(1)
	end

	return result.stdout:gsub("^\n", ""):gsub("\n$", "")
end

local function isDir(filePath: string): boolean
	return fs.exists(filePath) and fs.type(filePath) == "dir"
end

local function isFile(filePath: string): boolean
	return fs.exists(filePath) and fs.type(filePath) == "file"
end

local function ensureDir(filePath: string)
	if not isDir(filePath) then
		fs.createDirectory(filePath, {
			makeParents = true,
		})
	end
end

local function getPackageDirName(packagePath: string): string
	local cleaned = packagePath:gsub("/$", "")
	local parts = cleaned:split("/")
	return parts[#parts]
end

local function isValidPackagePath(packagePath: string): boolean
	return packagePath:find("Packages/_Index/", 1, true) ~= nil
		or packagePath:find("DevPackages/_Index/", 1, true) ~= nil
end

local function setupForPatching(packagePath: string)
	print("Initializing package for patching...")

	command("git", { "init" }, { cwd = packagePath })
	command("git", { "add", "-A" }, { cwd = packagePath })
	command("git", { "commit", "-m", "original" }, { cwd = packagePath })

	print()
	print("Package prepared for patching!")
	print("Make your changes to the package, then run this command again to generate the patch.")
end

local function generatePatch(packagePath: string, packageDirName: string)
	print("Generating patch...")

	command("git", { "add", "-A" }, { cwd = packagePath })
	local diff = command("git", { "diff", "--cached" }, {
		cwd = packagePath,
		captureOutput = true,
	})

	fs.removeDirectory(`{packagePath}/.git`, {
		recursive = true,
	})

	if diff == "" or diff == "\n" then
		print("No changes detected. Nothing to patch.")
		return
	end

	ensureDir(PATCHES_DIR)

	local patchFilePath = `{PATCHES_DIR}/{packageDirName}.patch`
	if isFile(patchFilePath) then
		local n = 2
		while isFile(`{PATCHES_DIR}/{packageDirName}_{n}.patch`) do
			n += 1
		end
		patchFilePath = `{PATCHES_DIR}/{packageDirName}_{n}.patch`
	end

	fs.writeStringToFile(patchFilePath, diff)

	print()
	print("Patch created successfully!")
	print(`  {patchFilePath}`)
	print()
	print("Run 'lute run install' to verify the patch applies cleanly.")
end

if rawArgs[1] == "--help" or rawArgs[1] == "-h" then
	printUsage()
	process.exit(0)
end

local packagePath = rawArgs[1]
if packagePath == nil or packagePath == "" then
	printUsage()
	process.exit(1)
end

if not isDir(packagePath) then
	fail(`Package directory not found: {packagePath}`)
end

if not isValidPackagePath(packagePath) then
	fail("Path must be inside Packages/_Index/ or DevPackages/_Index/")
end

local packageDirName = getPackageDirName(packagePath)
if isDir(`{packagePath}/.git`) then
	generatePatch(packagePath, packageDirName)
else
	setupForPatching(packagePath)
end
