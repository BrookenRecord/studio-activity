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

	local status, result = Jest.runCLI(root, {
		verbose = false,
		ci = false,
		-- selene: allow(global_usage)
		testPathPattern = _G.JEST_TEST_PATH_PATTERN,
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
