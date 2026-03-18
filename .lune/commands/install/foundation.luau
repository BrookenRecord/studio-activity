--[[
	Foundation Package Installation

	Installs Foundation packages from an upstream packages directory.
	Prunes non-exported packages and patches React references.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local exec = require("../../lib/process/exec")

local EXPORTED_PACKAGES = {
	"Foundation",
	"FoundationImages",
	"BuilderIcons",
	-- Some extra nice-to-haves
	"Signals",
	"SignalsReact",
	"ReactUtils",
	"Dash",
	"QRCode",
}

type PackageDependencies = { [string]: true }

local function _getFoundationDependencies(packagesPath: string): PackageDependencies
	local lock = serde.decode("toml", fs.readFile(`{packagesPath}/_Index/Foundation/lock.toml`))
	local deps: PackageDependencies = {}

	if lock and lock.dependencies then
		for _, dependencyString in lock.dependencies do
			local parts = dependencyString:split(" ")
			local packageSourceName = parts[2]
			deps[packageSourceName] = true
		end
	end

	return deps
end

local function pruneExportedPackages(packagesPath: string, quiet: boolean?)
	for _, filename in fs.readDir(packagesPath) do
		if filename == "_Index" then
			continue
		end

		local filePath = `{packagesPath}/{filename}`

		local isExported = false
		for _, exportedPackageName in EXPORTED_PACKAGES do
			if filename:match(exportedPackageName) then
				isExported = true
			end
		end

		if not isExported then
			exec.run("rm", { "-rf", filePath }, { quiet = quiet })
		end
	end
end

local function _prunePackageIndex(packagesPath: string, dependencies: PackageDependencies)
	local pathsToPrune: { string } = {}

	local packagesIndexPath = `{packagesPath}/_Index`

	for _, filename in fs.readDir(packagesIndexPath) do
		if filename == "Foundation" then
			continue
		end

		local filePath = `{packagesIndexPath}/{filename}`

		local fileNameParts = filename:split(".")
		local basename = fileNameParts[1]

		if not dependencies[basename] then
			table.insert(pathsToPrune, filePath)
		end
	end

	exec.run("rm", { "-rf", table.unpack(pathsToPrune) })
end

local TEMP_DIR = "tmp"

local function withTempDir(callback: (path: string) -> ())
	if fs.isDir(TEMP_DIR) then
		fs.removeDir(TEMP_DIR)
	end
	fs.writeDir(TEMP_DIR)
	local success, result = pcall(callback :: any, TEMP_DIR)
	fs.removeDir(TEMP_DIR)

	if not success then
		error(result)
	end
end

local function findAndReplace(filePath: string, match: string, replacement: string)
	local content = fs.readFile(filePath)
	content = content:gsub(match, replacement)
	fs.writeFile(filePath, content)
end

local function patchReact(packagesPath: string, quiet: boolean?)
	local reactLinkers = exec.run("find", { `{packagesPath}/_Index`, "-name", "React.lua" }, { quiet = quiet })
		:split("\n")

	for _, reactLinker in reactLinkers do
		if reactLinker == "" then
			continue
		end
		findAndReplace(reactLinker, `%["React"%]%["React"%]`, `["jsdotlua_react@17.2.1"]["react"]`)
	end
end

--[[
	Installs Foundation packages from an upstream packages directory.

	@param upstreamPath The path to the upstream packages directory
	@param dest The destination directory for the Foundation packages
	@param quiet Whether to suppress output
]]
local function installFoundation(upstreamPath: string, dest: string, quiet: boolean?)
	withTempDir(function(tempDir)
		local upstreamPackagesPath = exec.run("realpath", {
			upstreamPath,
		}, {
			quiet = quiet,
		})

		assert(fs.isDir(upstreamPackagesPath), `Could not find upstream packages at {upstreamPackagesPath}`)

		local packagesPath = `{tempDir}/Packages`
		exec.run("cp", { "-R", upstreamPackagesPath, packagesPath }, {
			quiet = quiet,
		})

		pruneExportedPackages(packagesPath, quiet)
		patchReact(packagesPath, quiet)

		exec.run("cp", { "-R", `{packagesPath}/*`, dest }, {
			quiet = quiet,
		})
	end)
end

return installFoundation
