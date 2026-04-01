--[[
	Install Command

	Installs all packages: Wally packages, package types, and Foundation.
]]

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local applyPatches = require("./install/patches")
local color = require("../utils/color")
local exec = require("../lib/process/exec")
local installFoundation = require("./install/foundation")
local rojo = require("../lib/project/rojo")

local install = {}

-- Metadata for help command
install.name = "install"
install.description = "Installs all packages (Wally, package types, Foundation)"
install.usage = "lune run install [--quiet]"

-- Argument definitions for CLI parsing
install.arguments = {
	{
		name = "quiet",
		kind = "flag",
		options = {
			help = "Suppress output",
			aliases = { "q" },
		},
	},
}

local PROJECT_FILE = "plugin/default.project.jsonc"
local SOURCEMAP_PATH = "plugin/generated/sourcemap.json"
local VERSION_PIN = "0.712.0.7120913"
local PACKAGE_DIRS = {
	"Packages",
	-- "DevPackages",
}
local ROBLOX_PACKAGES = {
	"Foundation",
	"FoundationImages",
	"BuilderIcons",
	-- Some extra nice-to-haves
	"ReactUtils",
	"QRCode",

	-- These are only included so the above dependencies work as expected.
	-- It seems like roblox-packages has a bug with its dependency
	-- resolution that is resulting in over-pruning
	"Promise",
	"Dash",
}

local function runWallyInstall(): (boolean, string)
	local result = process.exec("wally", { "install" }, {
		cwd = "plugin",
	})
	if not result.ok then
		return false, result.stderr
	end
	return true, result.stdout
end

local function runPackageTypes(dirPath: string, sourcemapPath: string): (boolean, string)
	local result = process.exec("wally-package-types", {
		"--sourcemap",
		`../{sourcemapPath}`,
		dirPath,
	}, {
		cwd = "plugin",
	})

	if not result.ok then
		return false, result.stderr
	end
	return true, result.stdout
end

export type Options = {
	quiet: boolean?,
}

--[[
	Installs all packages.

	@param options Configuration options
	@return True if successful, false otherwise
]]
function install.run(options_: Options?): boolean
	local options: Options = options_ or {}
	local quiet = if options.quiet ~= nil then options.quiet else false

	if not quiet then
		print(color.dim("Installing Wally packages..."))
	end

	local installResult, installStdout = runWallyInstall()
	if not installResult then
		if not quiet then
			print(color.bold(color.red("Failed to install packages")))
			stdio.write(installStdout)
		end
		return false
	end

	local sourcemapResult, sourcemapStdout = rojo.sourcemap({
		projectFile = PROJECT_FILE,
		output = SOURCEMAP_PATH,
		includeNonScripts = true,
	})
	if not sourcemapResult then
		if not quiet then
			print(color.bold(color.red("Failed to generate project sourcemap")))
			stdio.write(sourcemapStdout)
		end
		return false
	end

	for _, dir in PACKAGE_DIRS do
		local result, stdout = runPackageTypes(dir, SOURCEMAP_PATH)
		if not result then
			if not quiet then
				print(color.bold(color.red("Failed to generate package types for " .. dir)))
				stdio.write(stdout)
			end
			return false
		end
	end

	if not quiet then
		print(color.bold(color.white("Successfully installed Wally packages!")))
	end

	-- Apply patches to Wally packages
	if not quiet then
		print(color.dim("Applying package patches..."))
	end

	local patchResult = applyPatches(quiet)
	if not patchResult then
		if not quiet then
			print(color.bold(color.red("Failed to apply package patches")))
		end
		return false
	end

	if not quiet then
		print(color.bold(color.white("Successfully applied package patches!")))
	end

	-- Install Roblox packages to the OS temp directory and then extract Foundation
	local robloxPackagesPath = `/tmp/roblox-packages`
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
	exec.run("roblox-packages", robloxPackagesArgs)

	if not quiet then
		print(color.dim("Installing Foundation packages..."))
	end

	installFoundation(`{robloxPackagesPath}/Packages`, "plugin/Packages", quiet)

	if not quiet then
		print(color.bold(color.white("Successfully installed Foundation packages!")))
	end

	return true
end

return install
