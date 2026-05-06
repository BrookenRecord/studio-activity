local types = require("@self/types")

export type BuildContext = types.BuildContext

return {
	compileAsync = require("@self/compileAsync"),
	readBuildCacheAsync = require("@self/readBuildCacheAsync"),
	writeBuildCacheAsync = require("@self/writeBuildCacheAsync"),
	runBuildGroupAsync = require("@self/runBuildGroupAsync"),
}
