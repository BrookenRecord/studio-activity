local fs = require("@std/fs")
local path = require("@std/path")

local project = require("@repo/project")
local run = require("@scripts/lib/run")

local globalDefsPath = path.resolve("./plugin/generated/globalTypes.d.luau")
local globalDefsUrl = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.67.0/scripts/globalTypes.d.luau"

if not fs.exists(globalDefsPath) then
	run("curl", {
		"-sSL",
		"-o",
		globalDefsPath,
		globalDefsUrl,
	})
end

run("rojo", {
	"sourcemap",
	project.ROJO_BUILD_PROJECT,
	"-o",
	project.SOURCEMAP_PATH,
	"--absolute",
})

local defaultArgs: { string | path.Pathlike } = {
	"analyze",
	`--defs={globalDefsPath}`,
	"--settings=./.vscode/settings.json",
}

-- New solver analysis
-- TODO: Work out why Lute doesn't analyze
-- do
-- 	local args = table.clone(defaultArgs)
-- 	table.insert(args, "--platform=standard")
-- 	table.insert(args, "--flag:LuauSolverV2=true")
-- 	table.insert(args, path.resolve("./.lute"))

-- 	run("luau-lsp", { table.unpack(args) })
-- end

-- Old solver analysis
do
	local args = table.clone(defaultArgs)
	table.insert(args, `--sourcemap={project.SOURCEMAP_PATH}`)
	table.insert(args, path.resolve("./.lute"))
	table.insert(args, path.resolve("./plugin/src"))
	table.insert(args, path.resolve("./plugin/bin"))

	run("luau-lsp", { table.unpack(args) })
end
