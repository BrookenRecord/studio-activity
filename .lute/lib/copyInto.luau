local fs = require("@std/fs")
local path = require("@std/path")

local function copyInto(src: path.Pathlike, dest: path.Pathlike)
	if fs.type(src) == "dir" then
		fs.createDirectory(dest, {
			makeParents = true,
		})

		for _, file in fs.listDirectory(src) do
			local filePath = path.join(src, file.name)
			local fileDest = path.join(dest, file.name)

			if file.type == "dir" then
				copyInto(filePath, fileDest)
			else
				fs.copy(filePath, fileDest)
			end
		end
	else
		fs.copy(src, dest)
	end
end

return copyInto
