--[[
	Help Command

	Displays a list of all available commands and their descriptions.
	Dynamically discovers commands from the commands/ directory.

	Note: Run this command from inside the .lune directory:
	  cd .lune && lune run help
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local cli = require("./lib/cli/parser")
local color = require("./utils/color")

-- Detect the commands directory path based on where we're running from
local function getCommandsPath(): string
	if fs.isDir("commands") then
		return "commands"
	elseif fs.isDir(".lune/commands") then
		return ".lune/commands"
	else
		error("Could not find commands directory. Please run from the .lune directory.")
	end
end

--[[
	Discovers all commands from the commands/ directory.

	@return A list of command metadata sorted alphabetically
]]
local function discoverCommands(): { { name: string, description: string, usage: string } }
	local commands = {}
	local commandsPath = getCommandsPath()

	for _, entry in fs.readDir(commandsPath) do
		-- Handle both .luau files and directories (with init.luau)
		local name = entry:gsub("%.luau$", "")
		local success, command = pcall(require, `./commands/{name}`)

		if success and type(command) == "table" and command.name then
			table.insert(commands, {
				name = command.name,
				description = command.description or "",
				usage = command.usage or `lune run {command.name}`,
			})
		end
	end

	-- Sort alphabetically
	table.sort(commands, function(a, b)
		return a.name < b.name
	end)

	return commands
end

local function printGeneralHelp()
	local commands = discoverCommands()

	print(color.bold("Studio Activity CLI"))
	print()
	print("A collection of development tools for building, testing, and managing the project.")
	print()
	print(color.bold("Usage:") .. " lune run <command> [arguments]")
	print()
	print(color.bold("Commands:"))
	print()

	-- Find longest name for alignment
	local maxLen = 0
	for _, cmd in commands do
		maxLen = math.max(maxLen, #cmd.name)
	end

	for _, cmd in commands do
		local padding = string.rep(" ", maxLen - #cmd.name + 2)
		print(`  {color.cyan(cmd.name)}{padding}{cmd.description}`)
	end

	print()
	print(color.dim("Run 'lune run <command> --help' for command-specific options."))
end

local function printCommandHelp(commandName: string)
	local success, command = pcall(require, `./commands/{commandName}`)

	if not success or type(command) ~= "table" or not command.name then
		print(color.bold(color.red(`Unknown command: {commandName}`)))
		print()
		print("Run 'lune run help' to see available commands.")
		process.exit(1)
		return
	end

	print(color.bold(command.name))
	print()
	print(command.description)
	print()
	print(color.bold("Usage:") .. ` {command.usage}`)
	print()
	print(color.dim(`Run 'lune run {command.name} --help' for detailed options.`))
end

local function main()
	local parser = cli.parser()
	parser:setDescription("Displays available commands and their descriptions")
	parser:setCommandName("lune run help")
	parser:add("command", "positional", {
		help = "The command to get help for",
		required = false,
	})
	parser:parse(process.args)

	local commandName = parser:get("command")
	if commandName then
		printCommandHelp(commandName)
	else
		printGeneralHelp()
	end
end

main()
