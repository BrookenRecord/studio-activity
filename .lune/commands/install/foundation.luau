--[[
	Foundation Package Installation

	Installs Foundation packages from an upstream packages directory.
	Patches React references to point to the Wally-installed React package.
]]

local fs = require("@lune/fs")

local exec = require("../../lib/process/exec")

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

		patchReact(packagesPath, quiet)

		exec.run("cp", { "-R", `{packagesPath}/*`, dest }, {
			quiet = quiet,
		})
	end)
end

return installFoundation
