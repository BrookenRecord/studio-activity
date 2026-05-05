--[[
	Package Redirection

	Wally has no support for deduping packages published by different
	authors, or for patching transitive dependency references after
	install. This module fills that gap: it deletes a set of installed
	package directories under `<packagesDir>/_Index/` and rewrites every
	top-level `*.lua` shim so references to the removed names are
	redirected to their replacements.

	Two entry points:

	  redirectPackages.apply(packagesDir, { ["old@1"] = "new@2" }, quiet)
	    - Low-level primitive. Caller supplies the rename map directly.

	  redirectPackages.byAuthor(packagesDir, "fromAuthor", "toAuthor", quiet)
	    - Convenience. Discovers `<fromAuthor>_<name>@<v>` directories and
	      pairs each with the unique `<toAuthor>_<name>@<v>` sibling, then
	      delegates to `apply`. This matches the canonical case of
	      converging two registries that publish overlapping packages.
]]

local fs = require("@lune/fs")

local color = require("../../utils/color")

--[[
	Replaces every plain-text occurrence of `needle` in `content` with
	`replacement`. Avoids string.gsub so callers do not have to escape
	pattern metacharacters in package names like `@` and `.`.
]]
local function plainReplaceAll(content: string, needle: string, replacement: string): string
	if not string.find(content, needle, 1, true) then
		return content
	end
	return table.concat(content:split(needle), replacement)
end

--[[
	Rewrites a single shim file in place, applying every rename in the map.
]]
local function rewriteShim(path: string, renames: { [string]: string })
	local original = fs.readFile(path)
	local contents = original
	for from, to in renames do
		contents = plainReplaceAll(contents, from, to)
	end
	if contents ~= original then
		fs.writeFile(path, contents)
	end
end

--[[
	Walks every top-level `.lua` shim under `<packagesDir>/<pkg>/` and
	rewrites references to renamed packages.
]]
local function rewriteAllShims(packagesDir: string, renames: { [string]: string })
	for _, pkg in fs.readDir(packagesDir) do
		local pkgPath = `{packagesDir}/{pkg}`
		if not fs.isDir(pkgPath) then
			continue
		end

		for _, file in fs.readDir(pkgPath) do
			if not file:match("%.lua$") then
				continue
			end
			local filePath = `{pkgPath}/{file}`
			if fs.isFile(filePath) then
				rewriteShim(filePath, renames)
			end
		end
	end
end

local redirectPackages = {}

--[[
	Applies an explicit rename map: deletes each `from` directory under
	`packagesDir` and rewrites every shim to point at the `to` directory.

	@param packagesDir Path to the package index (e.g. "plugin/Packages/_Index")
	@param renames Map of directory names to redirect (from -> to)
	@param quiet Whether to suppress output
	@return True on success, false on error
]]
function redirectPackages.apply(packagesDir: string, renames: { [string]: string }, quiet: boolean?): boolean
	if next(renames) == nil then
		return true
	end

	if not fs.isDir(packagesDir) then
		if not quiet then
			print(color.yellow(`  Package directory not found: {packagesDir}`))
		end
		return false
	end

	if not quiet then
		for from, to in renames do
			print(color.dim(`  Redirecting {from} -> {to}`))
		end
	end

	-- Delete first, then rewrite. Walking the index after deletion means we
	-- never try to read a shim inside a directory that no longer exists.
	for from in renames do
		local pkgPath = `{packagesDir}/{from}`
		if fs.isDir(pkgPath) then
			fs.removeDir(pkgPath)
		end
	end

	rewriteAllShims(packagesDir, renames)

	return true
end

--[[
	Builds a rename map by pairing every `<fromAuthor>_<name>@<v>` directory
	in `packagesDir` with its unique `<toAuthor>_<name>@<v>` sibling, then
	delegates to `redirectPackages.apply`.

	Authors without a matching sibling are left alone (no entry in the map).
	Errors if more than one sibling matches a single from-author package.

	@param packagesDir Path to the package index (e.g. "plugin/Packages/_Index")
	@param fromAuthor The author whose packages should be removed
	@param toAuthor The author whose packages should be kept
	@param quiet Whether to suppress output
	@return True on success, false on error
]]
function redirectPackages.byAuthor(packagesDir: string, fromAuthor: string, toAuthor: string, quiet: boolean?): boolean
	if not fs.isDir(packagesDir) then
		return true
	end

	local entries = fs.readDir(packagesDir)
	local fromPattern = `^{fromAuthor}_(.-)@`
	local toPrefix = `{toAuthor}_`

	local renames: { [string]: string } = {}
	for _, entry in entries do
		local depName = entry:match(fromPattern)
		if depName == nil then
			continue
		end
		if not fs.isDir(`{packagesDir}/{entry}`) then
			continue
		end

		local siblingPrefix = `{toPrefix}{depName}@`
		local matches: { string } = {}
		for _, candidate in entries do
			if candidate:sub(1, #siblingPrefix) == siblingPrefix and fs.isDir(`{packagesDir}/{candidate}`) then
				table.insert(matches, candidate)
			end
		end

		if #matches == 0 then
			continue
		end
		if #matches > 1 then
			if not quiet then
				print(
					color.bold(
						color.red(
							`Expected at most one {toAuthor} sibling for {entry}, found {#matches}: `
								.. table.concat(matches, ", ")
						)
					)
				)
			end
			return false
		end
		renames[entry] = matches[1]
	end

	return redirectPackages.apply(packagesDir, renames, quiet)
end

return redirectPackages
