local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local project = require("@repo/project")
local types = require("@scripts/lib/build-system/types")

local function writeBuildVarsAsync(context: types.BuildContext)
	local contents = json.serialize(context.vars :: any, true)

	local relativePath = path.relative(project.PLUGIN_PATH, project.BUILD_VARS_PATH)
	fs.writeStringToFile(path.join(context.dest, relativePath), contents)
end

return writeBuildVarsAsync
