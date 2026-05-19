local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Jest = require(Packages.Dev.Jest)

local function runTests()
	local root = script.Parent.Parent.Source

	-- selene: allow(global_usage)
	_G.__DEV__ = true
	-- selene: allow(global_usage)
	_G.__ROACT_17_MOCK_SCHEDULER__ = true

	Charm.flags.strict = true
	Charm.flags.frozen = true

	-- selene: allow(global_usage)
	local testPathPattern = _G.JEST_TEST_PATH_PATTERN

	local status, result = Jest.runCLI(root, {
		verbose = false,
		ci = false,
		testPathPattern = if testPathPattern ~= "__null__" then testPathPattern else nil,
	}, { root }):awaitStatus()

	if status == "Rejected" then
		print(result)
	end

	if status ~= "Resolved" or result.results.numFailedTestSuites > 0 or result.results.numFailedTests > 0 then
		error(1)
	end
end

return {
	runTests = runTests,
}
