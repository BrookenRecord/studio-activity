local path = require("@std/path")
local process = require("@std/process")
local richterm = require("@batteries/richterm")

type Options = {
	cwd: path.Pathlike?,
	env: { [string]: string }?,
	captureOutput: boolean?,

	-- @DEPRECATED: Use `captureOutput` instead.
	stdio: any,
}

--[[
	By default this function will return nil, but in the case where you want to
	capture stdout for parsing you can set `captureOutput = true`.
--]]
local function run(program: string, params: { string | number | boolean | path.Pathlike }, options: Options?): string?
	local stringParams: { string } = {}
	for _, param in params do
		table.insert(stringParams, tostring(param))
	end

	local captureOutput = if options and options.captureOutput then options.captureOutput else false

	local command = `{program} {table.concat(stringParams, " ")}`
	print(richterm.dim(`> {command}`))

	local stdio = "inherit"
	if options then
		if options.captureOutput then
			stdio = "default"
		elseif options.stdio then
			stdio = options.stdio
		end
	end

	local result = process.system(command, {
		stdio = stdio :: any,
		cwd = if options and options.cwd then tostring(options.cwd) else nil,
		env = if options then options.env else nil,
	})

	if result.ok then
		local stdout = result.stdout:gsub("^\n", ""):gsub("\n$", "")

		-- Lute only supports capturing stdout when `stdio = "default"`, and
		-- this case also means that Lute won't stream the output to the
		-- terminal itself. So we do it manually to improve the ergonomics.
		if captureOutput then
			print(stdout)
		end

		return stdout
	else
		error(result.stderr, 2)
	end
end

return run
