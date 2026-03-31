--[[
	Wally Package Patching

	Discovers git-format patch files in plugin/patches/ and applies them
	to the corresponding packages in plugin/Packages/_Index/.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local color = require("../../utils/color")

local PATCHES_DIR = "plugin/patches"
local PACKAGES_INDEX_DIR = "plugin/Packages/_Index"

--[[
	Applies all patches from plugin/patches/ to installed Wally packages.

	Patch filenames must match _Index directory names exactly:
	  plugin/patches/jsdotlua_jest-runtime@3.10.0.patch
	  → applies to plugin/Packages/_Index/jsdotlua_jest-runtime@3.10.0/

	@param quiet Whether to suppress output
	@return True if all patches applied successfully, false otherwise
]]
local function applyPatches(quiet: boolean?): boolean
	if not fs.isDir(PATCHES_DIR) then
		return true
	end

	local patchFiles: { string } = {}
	for _, filename in fs.readDir(PATCHES_DIR) do
		if filename:match("%.patch$") then
			table.insert(patchFiles, filename)
		end
	end

	if #patchFiles == 0 then
		return true
	end

	table.sort(patchFiles)

	for _, patchFile in patchFiles do
		local targetDirName = patchFile:gsub("%.patch$", "")
		local targetPath = `{PACKAGES_INDEX_DIR}/{targetDirName}`

		if not fs.isDir(targetPath) then
			if not quiet then
				print(color.yellow(`  Warning: Package directory not found for patch: {patchFile}`))
				print(color.yellow(`  Expected: {targetPath}`))
			end
			continue
		end

		if not quiet then
			print(color.dim(`  Applying {patchFile}`))
		end

		local patchFilePath = `{PATCHES_DIR}/{patchFile}`
		local result = process.exec("git", {
			"apply",
			"--directory",
			targetPath,
			patchFilePath,
		})

		if not result.ok then
			if not quiet then
				print(color.red(`  Failed to apply patch: {patchFile}`))
				print(color.red(`  {result.stderr}`))
			end
			return false
		end
	end

	return true
end

return applyPatches
