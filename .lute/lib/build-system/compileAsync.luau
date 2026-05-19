local fs = require("@std/fs")
local path = require("@std/path")

local copyInto = require("@scripts/lib/copyInto")
local project = require("@repo/project")
local run = require("@scripts/lib/run")
local runBuildGroupAsync = require("@scripts/lib/build-system/runBuildGroupAsync")
local types = require("@scripts/lib/build-system/types")
local writeBuildVarsAsync = require("@scripts/lib/build-system/writeBuildVarsAsync")

type BuildContext = types.BuildContext

local function compileAsync(context: BuildContext)
	if context.shouldRebuild then
		fs.removeDirectory(context.dest, {
			recursive = true,
		})
	end
	fs.createDirectory(context.dest, {
		makeParents = true,
	})

	copyInto("plugin/bin", path.join(context.dest, "bin"))
	copyInto("plugin/src", path.join(context.dest, "src"))
	copyInto("plugin/resources", path.join(context.dest, "resources"))

	writeBuildVarsAsync(context)

	runBuildGroupAsync({
		name = "🚚 dependencies",
		paths = {
			project.PACKAGES_PATH,
			project.DEV_PACKAGES_PATH,
		},
		context = context,
		step = function(group)
			for _, filePath in group.paths do
				local relativePath = path.relative(project.PLUGIN_PATH, filePath)
				copyInto(filePath, path.join(context.dest, relativePath))
			end
		end,
	})

	if context.channel == "prod" then
		runBuildGroupAsync({
			name = `✂️ prune build`,
			paths = { context.dest },
			context = context,
			step = function()
				for _, pattern in project.PROD_CONFIG.prunedFiles do
					run("find", { context.dest, "-type", "f", "-name", `"{pattern}"`, "-delete" })
				end
			end,
		})

		for _, dir in project.PROD_CONFIG.prunedDirs do
			local relativePath = path.relative(project.PLUGIN_PATH, dir)

			fs.removeDirectory(path.join(context.dest, relativePath), {
				recursive = true,
			})
		end
	end
end

return compileAsync
