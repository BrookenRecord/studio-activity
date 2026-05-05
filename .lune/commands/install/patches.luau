--[[
	Wally Package Patching

	Discovers git-format patch files in plugin/patches/ and applies them
	to the corresponding packages in plugin/Packages/_Index/.

	Application is resilient to upstream drift:
	  1. First try a strict `git apply` -- the cheap, atomic happy path.
	  2. On failure, retry with `git apply --reject` so the hunks that
	     still match are applied and any drifted hunks are written to
	     `<file>.rej` next to the source. The install then continues
	     with a warning so the next step (`lune run patch <pkg>` to
	     regenerate the patch) is obvious.

	Note: `git apply --3way` would be nicer (inline conflict markers)
	but it requires the patch's recorded blob hashes to be present in
	the local object database. Our patches are generated in an ephemeral
	`git init` repo that is deleted after `git diff --cached`, and
	plugin/Packages/_Index is gitignored, so those blobs are never
	available at apply time. `--reject` gives equivalent recoverability
	via sidecar `.rej` files.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local color = require("../../utils/color")

local PATCHES_DIR = "plugin/patches"
local PACKAGES_INDEX_DIR = "plugin/Packages/_Index"

--[[
	Recursively collects any `*.rej` files under a directory.
]]
local function collectRejects(root: string, out: { string })
	if not fs.isDir(root) then
		return
	end
	for _, entry in fs.readDir(root) do
		local entryPath = `{root}/{entry}`
		if fs.isDir(entryPath) then
			collectRejects(entryPath, out)
		elseif entry:match("%.rej$") then
			table.insert(out, entryPath)
		end
	end
end

--[[
	Applies a single patch file to the target package directory, preferring
	a clean apply but falling back to `--reject` so that drift is recoverable
	rather than fatal.

	Returns:
	  status: "clean" | "conflicts" | "failed"
	  message: human-readable detail (stderr from git, or a summary)
	  rejects: list of `.rej` files produced under targetPath, if any
]]
local function applyPatch(patchFilePath: string, targetPath: string): (string, string, { string })
	local strict = process.exec("git", {
		"apply",
		"--directory",
		targetPath,
		patchFilePath,
	})
	if strict.ok then
		return "clean", strict.stdout, {}
	end

	-- Lenient retry: apply hunks that still match and dump the rest into
	-- sibling `*.rej` files. Git exits non-zero whenever any hunk is
	-- rejected, but the partial apply succeeds.
	local lenient = process.exec("git", {
		"apply",
		"--reject",
		"--directory",
		targetPath,
		patchFilePath,
	})

	local rejects: { string } = {}
	collectRejects(targetPath, rejects)

	if #rejects > 0 then
		return "conflicts", lenient.stderr, rejects
	end

	if lenient.ok then
		return "clean", lenient.stdout, {}
	end

	-- Neither attempt produced anything useful (e.g. patch references a
	-- file that does not exist). Surface the original strict-apply error.
	return "failed", strict.stderr, {}
end

--[[
	Applies all patches from plugin/patches/ to installed Wally packages.

	Patch filenames must match _Index directory names exactly:
	  plugin/patches/jsdotlua_jest-runtime@3.10.0.patch
	  → applies to plugin/Packages/_Index/jsdotlua_jest-runtime@3.10.0/

	@param quiet Whether to suppress output
	@return True if all patches applied without unrecoverable failures.
	        Patches that produced conflict markers or `.rej` files are
	        reported as warnings but do not fail the install.
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

	local conflictedPatches: { { patch: string, rejects: { string } } } = {}
	local failedPatches: { { patch: string, message: string } } = {}

	for _, patchFile in patchFiles do
		local baseName = patchFile:gsub("%.patch$", "")
		local targetDirName = baseName
		local targetPath = `{PACKAGES_INDEX_DIR}/{targetDirName}`

		-- If no directory matches the full name, strip sequence number suffix (e.g., "_2")
		if not fs.isDir(targetPath) then
			targetDirName = baseName:gsub("_%d+$", "")
			targetPath = `{PACKAGES_INDEX_DIR}/{targetDirName}`
		end

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
		local status, message, rejects = applyPatch(patchFilePath, targetPath)

		if status == "clean" then
			continue
		elseif status == "conflicts" then
			table.insert(conflictedPatches, { patch = patchFile, rejects = rejects })
			if not quiet then
				print(color.yellow(`  Conflict: {patchFile} applied with drift`))
				for _, rej in rejects do
					print(color.yellow(`    rejected hunks: {rej}`))
				end
			end
		else
			table.insert(failedPatches, { patch = patchFile, message = message })
			if not quiet then
				print(color.red(`  Failed to apply patch: {patchFile}`))
				print(color.red(`  {message}`))
			end
		end
	end

	if #conflictedPatches > 0 and not quiet then
		print()
		print(color.bold(color.yellow("Some patches drifted from upstream and need attention:")))
		for _, entry in conflictedPatches do
			print(color.yellow(`  - {entry.patch}`))
		end
		print(color.dim("  Resolve the conflicts (or apply the .rej hunks by hand), then run"))
		print(color.dim("  `lune run patch plugin/Packages/_Index/<pkg>` twice to regenerate."))
	end

	return #failedPatches == 0
end

return applyPatches
