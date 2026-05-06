local fs = require("@std/fs")
local path = require("@std/path")

local function findWhere(rootDirPath: path.Pathlike, matcher: (path: path.Pathlike) -> boolean?): { path.Path }
	assert(fs.type(rootDirPath) == "dir", "rootDirPath must be a directory")

	local descendants: { path.Path } = {}

	local function search(rootPath: path.Pathlike)
		local isMatch = matcher(rootPath)
		if isMatch == nil then
			return
		elseif isMatch == true then
			table.insert(descendants, path.normalize(rootPath))
		end

		if fs.type(rootPath) == "dir" then
			for _, child in fs.listDirectory(rootPath) do
				search(path.join(rootPath, child.name))
			end
		end
	end

	search(rootDirPath)

	return descendants
end

return findWhere
