--[[
	Patch Entry Point

	Creates or updates a patch for a Wally package.
]]

local process = require("@lune/process")

local cli = require("./lib/cli/parser")
local command = require("./commands/patch")

local function main()
	local parser = cli.parser()
	parser:setDescription(command.description)
	parser:setCommandName(`lune run {command.name}`)

	for _, arg: any in command.arguments do
		parser:add(arg.name, arg.kind, arg.options)
	end

	parser:parse(process.args)

	command.run({
		packagePath = parser:get("package-path") :: string,
	})
end

main()
