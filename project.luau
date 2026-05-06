local path = require("@std/path")

return {
	REPO_PATH = path.resolve("."),
	SOURCE_PATH = path.resolve("./plugin/src"),
	BUILD_PATH = path.resolve("./plugin/build"),
	BUILD_CACHE_PATH = path.resolve("./plugin/build/build-cache.json"),
	PACKAGES_PATH = path.resolve("./plugin/Packages"),
	DEV_PACKAGES_PATH = path.resolve("./plugin/DevPackages"),
	ROBLOX_PACKAGES_VERSION = "0.715.1.7151119",
	SCRIPTS_PATH = path.resolve("./.lute"),

	PLUGIN_FILENAME = "StudioActivity.rbxm",

	SOURCEMAP_PATH = path.resolve("./sourcemap.json"),
	DARKLUA_SOURCEMAP_PATH = path.resolve("./sourcemap-darklua.json"),

	ROJO_BUILD_PROJECT = path.resolve("./plugin/build.project.json"),
	ROJO_TESTS_PROJECT = path.resolve("./plugin/tests.project.json"),

	FOLDERS_TO_LINT = {
		".lune",
		".lute",
		"plugin/bin",
		"plugin/src",
	},

	PROD_CONFIG = {
		prunedDirs = {
			path.resolve("./plugin/DevPackages"),
		},
		prunedFiles = {
			"*.test.lua*",
			"*.story.lua*",
			"*.storybook.lua*",
			"jest.config.lua*",
		},
	},
}
