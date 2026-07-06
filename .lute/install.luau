local cli = require("@batteries/cli")
local fs = require("@std/fs")
local process = require("@std/process")

local project = require("@repo/project")

local args = cli.parser()
args:add("quiet", "flag", {
	help = "Suppress output",
	aliases = { "q" },
})
args:parse({ ... })

local quiet = args:has("quiet")

local VERSION_PIN = "0.722.0.7221024"
local PATCHES_DIR = "plugin/patches"
local PACKAGE_INDEX_DIRS = {
	"plugin/Packages/_Index",
	"plugin/DevPackages/_Index",
}
local PACKAGE_DIRS = {
	"Packages",
	"DevPackages",
}
local ROBLOX_PACKAGES = {
	"Foundation",
	"FoundationImages",
	"BuilderIcons",
	"ReactUtils",
	"QRCode",
	"Promise",
	"Dash",
}

type CommandOptions = {
	cwd: string?,
	captureOutput: boolean?,
}

local function log(message: string)
	if not quiet then
		print(message)
	end
end

local function command(program: string, params: { string }, options: CommandOptions?): string
	local commandLine = `{program} {table.concat(params, " ")}`
	if not quiet then
		print(`RUN > {commandLine}`)
	end

	local captureOutput = options ~= nil and options.captureOutput == true
	local result = process.system(commandLine, {
		stdio = if captureOutput or quiet then "default" else "inherit",
		cwd = if options then options.cwd else nil,
	})

	if not result.ok then
		if result.stderr ~= "" then
			print(result.stderr)
		end
		process.exit(1)
	end

	local stdout = result.stdout:gsub("^\n", ""):gsub("\n$", "")
	if captureOutput and not quiet and stdout ~= "" then
		print(stdout)
	end
	return stdout
end

local function commandResult(program: string, params: { string }): (boolean, string, string)
	local commandLine = `{program} {table.concat(params, " ")}`
	local result = process.system(commandLine, {
		stdio = "default",
	})
	return result.ok, result.stdout, result.stderr
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

local function removeDir(filePath: string)
	if isDir(filePath) then
		fs.removeDirectory(filePath, {
			recursive = true,
		})
	end
end

local function readFile(filePath: string): string
	return fs.readFileToString(filePath)
end

local function writeFile(filePath: string, contents: string)
	fs.writeStringToFile(filePath, contents)
end

local function replacePlain(content: string, needle: string, replacement: string): string
	if not string.find(content, needle, 1, true) then
		return content
	end
	return table.concat(content:split(needle), replacement)
end

local function patchReact(packagesPath: string)
	local reactLinkers = command("find", { `{packagesPath}/_Index`, "-name", "React.lua" }, {
		captureOutput = true,
	}):split("\n")

	for _, reactLinker in reactLinkers do
		if reactLinker == "" then
			continue
		end

		local content = readFile(reactLinker)
		content = content:gsub(`%["React"%]%["React"%]`, `["jsdotlua_react@17.2.1"]["react"]`)
		writeFile(reactLinker, content)
	end
end

local function installFoundation(upstreamPath: string, dest: string)
	local tempDir = "tmp"
	removeDir(tempDir)
	ensureDir(tempDir)

	local ok, err = pcall(function()
		local upstreamPackagesPath = command("realpath", { upstreamPath }, {
			captureOutput = true,
		})
		assert(isDir(upstreamPackagesPath), `Could not find upstream packages at {upstreamPackagesPath}`)

		local packagesPath = `{tempDir}/Packages`
		command("cp", { "-R", upstreamPackagesPath, packagesPath })
		patchReact(packagesPath)
		command("cp", { "-R", `{packagesPath}/*`, dest })
	end)

	removeDir(tempDir)

	if not ok then
		error(err, 0)
	end
end

local function rewriteShim(filePath: string, renames: { [string]: string })
	local original = readFile(filePath)
	local contents = original
	for from, to in renames do
		contents = replacePlain(contents, from, to)
	end
	if contents ~= original then
		writeFile(filePath, contents)
	end
end

local function rewriteAllShims(packagesDir: string, renames: { [string]: string })
	for _, pkg in fs.listDirectory(packagesDir) do
		local pkgPath = `{packagesDir}/{pkg.name}`
		if pkg.type ~= "dir" then
			continue
		end

		for _, file in fs.listDirectory(pkgPath) do
			if not file.name:match("%.lua$") then
				continue
			end

			local filePath = `{pkgPath}/{file.name}`
			if isFile(filePath) then
				rewriteShim(filePath, renames)
			end
		end
	end
end

local function redirectByAuthor(packageDirs: { string }, fromAuthor: string, toAuthor: string): boolean
	local entrySet: { [string]: boolean } = {}
	local anyDirExists = false

	for _, dir in packageDirs do
		if not isDir(dir) then
			continue
		end
		anyDirExists = true
		for _, entry in fs.listDirectory(dir) do
			if entry.type == "dir" then
				entrySet[entry.name] = true
			end
		end
	end

	if not anyDirExists then
		return true
	end

	local fromPattern = `^{fromAuthor}_(.-)@`
	local toPrefix = `{toAuthor}_`
	local renames: { [string]: string } = {}

	for entry in entrySet do
		local depName = entry:match(fromPattern)
		if depName == nil then
			continue
		end

		local siblingPrefix = `{toPrefix}{depName}@`
		local matches: { string } = {}
		for candidate in entrySet do
			if candidate:sub(1, #siblingPrefix) == siblingPrefix then
				table.insert(matches, candidate)
			end
		end

		if #matches == 0 then
			continue
		end
		if #matches > 1 then
			print(
				`Expected at most one {toAuthor} sibling for {entry}, found {#matches}: {table.concat(matches, ", ")}`
			)
			return false
		end
		renames[entry] = matches[1]
	end

	if next(renames) == nil then
		return true
	end

	for from, to in renames do
		log(`  Redirecting {from} -> {to}`)
	end

	for from in renames do
		for _, dir in packageDirs do
			local pkgPath = `{dir}/{from}`
			if isDir(pkgPath) then
				removeDir(pkgPath)
			end
		end
	end

	for _, dir in packageDirs do
		if isDir(dir) then
			rewriteAllShims(dir, renames)
		end
	end

	return true
end

local function collectRejects(root: string, out: { string })
	if not isDir(root) then
		return
	end

	for _, entry in fs.listDirectory(root) do
		local entryPath = `{root}/{entry.name}`
		if entry.type == "dir" then
			collectRejects(entryPath, out)
		elseif entry.name:match("%.rej$") then
			table.insert(out, entryPath)
		end
	end
end

local function resolveTargetPath(baseName: string): string?
	local fallbackName = baseName:gsub("_%d+$", "")

	for _, indexDir in PACKAGE_INDEX_DIRS do
		local candidate = `{indexDir}/{baseName}`
		if isDir(candidate) then
			return candidate
		end

		if fallbackName ~= baseName then
			candidate = `{indexDir}/{fallbackName}`
			if isDir(candidate) then
				return candidate
			end
		end
	end

	return nil
end

local function applyPatch(patchFilePath: string, targetPath: string): (string, string, { string })
	local strictOk, strictStdout, strictStderr = commandResult("git", {
		"apply",
		"--directory",
		targetPath,
		patchFilePath,
	})
	if strictOk then
		return "clean", strictStdout, {}
	end

	local lenientOk, lenientStdout, lenientStderr = commandResult("git", {
		"apply",
		"--reject",
		"--directory",
		targetPath,
		patchFilePath,
	})
	local rejects: { string } = {}
	collectRejects(targetPath, rejects)

	if #rejects > 0 then
		return "conflicts", lenientStderr, rejects
	end
	if lenientOk then
		return "clean", lenientStdout, {}
	end
	return "failed", strictStderr, {}
end

local function applyPatches(): boolean
	if not isDir(PATCHES_DIR) then
		return true
	end

	local patchFiles: { string } = {}
	for _, entry in fs.listDirectory(PATCHES_DIR) do
		if entry.type == "file" and entry.name:match("%.patch$") then
			table.insert(patchFiles, entry.name)
		end
	end
	table.sort(patchFiles)

	local conflictedPatches: { { patch: string, rejects: { string } } } = {}
	local failedPatches: { { patch: string, message: string } } = {}

	for _, patchFile in patchFiles do
		local baseName = patchFile:gsub("%.patch$", "")
		local targetPath = resolveTargetPath(baseName)

		if targetPath == nil then
			table.insert(failedPatches, {
				patch = patchFile,
				message = `Package directory not found. Searched: {table.concat(PACKAGE_INDEX_DIRS, ", ")}`,
			})
			log(`  Failed to apply patch: {patchFile}`)
			continue
		end

		log(`  Applying {patchFile}`)

		local status, message, rejects = applyPatch(`{PATCHES_DIR}/{patchFile}`, targetPath)
		if status == "clean" then
			continue
		elseif status == "conflicts" then
			table.insert(conflictedPatches, { patch = patchFile, rejects = rejects })
			log(`  Conflict: {patchFile} applied with drift`)
			for _, rej in rejects do
				log(`    rejected hunks: {rej}`)
			end
		else
			table.insert(failedPatches, { patch = patchFile, message = message })
			log(`  Failed to apply patch: {patchFile}`)
			log(`  {message}`)
		end
	end

	if #conflictedPatches > 0 and not quiet then
		print()
		print("Some patches drifted from upstream and need attention:")
		for _, entry in conflictedPatches do
			print(`  - {entry.patch}`)
		end
		print("  Resolve the conflicts (or apply the .rej hunks by hand), then run")
		print("  `lute run patch <packages>/_Index/<pkg>` twice to regenerate.")
	end

	return #failedPatches == 0 and #conflictedPatches == 0
end

local function generateSourcemap()
	ensureDir("plugin/generated")
	command("rojo", {
		"sourcemap",
		tostring(project.ROJO_BUILD_PROJECT),
		"-o",
		tostring(project.SOURCEMAP_PATH),
		"--absolute",
		"--include-non-scripts",
	})
end

log("Installing Lute packages...")
command("lute", { "pkg", "install" })

log("Installing Wally packages...")
command("wally", { "install" }, {
	cwd = "plugin",
})

generateSourcemap()

for _, dir in PACKAGE_DIRS do
	command("wally-package-types", {
		"--sourcemap",
		tostring(project.SOURCEMAP_PATH),
		dir,
	}, {
		cwd = "plugin",
	})
end

log("Successfully installed Wally packages!")

local robloxPackagesPath = "/tmp/roblox-packages"
local robloxPackagesArgs = {
	"install",
	robloxPackagesPath,
	"--version",
	VERSION_PIN,
}
for _, pkg in ROBLOX_PACKAGES do
	table.insert(robloxPackagesArgs, "-d")
	table.insert(robloxPackagesArgs, pkg)
end
command("roblox-packages", robloxPackagesArgs)

log("Installing Foundation packages...")
installFoundation(`{robloxPackagesPath}/Packages`, "plugin/Packages")
log("Successfully installed Foundation packages!")

log("Redirecting jsdotlua packages to haedrix...")
if not redirectByAuthor({ "plugin/Packages/_Index", "plugin/DevPackages/_Index" }, "jsdotlua", "haedrix") then
	print("Failed to redirect packages")
	process.exit(1)
end

log("Applying package patches...")
if not applyPatches() then
	print("Failed to apply package patches")
	process.exit(1)
end
log("Successfully applied package patches!")

generateSourcemap()
