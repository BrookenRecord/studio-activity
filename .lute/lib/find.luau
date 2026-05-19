local path = require("@std/path")

local findWhere = require("./findWhere")

local function find(root: path.Pathlike, filenamePattern: string): { path.Path }
	return findWhere(root, function(filePath)
		local fileName = path.basename(filePath)
		return fileName and fileName:match(filenamePattern) ~= nil
	end)
end

return find
