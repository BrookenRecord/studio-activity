local fs = require("@std/fs")
local path = require("@std/path")
local richterm = require("@batteries/richterm")
local task = require("@lute/task")

local getDescendants = require("./getDescendants")

type Options = {
	roots: { path.Pathlike },
	excludedFilePatterns: { string }?,
	onChanged: ((filePath: path.Path) -> ())?,
}

local function getWatchedFolders(options: Options)
	local watchedFolders = {}

	for _, root in options.roots do
		for _, descendantPath in getDescendants(root) do
			if fs.type(descendantPath) == "dir" then
				local isIncluded = true

				if options.excludedFilePatterns then
					for _, excludedFilePattern in options.excludedFilePatterns do
						if tostring(descendantPath):match(excludedFilePattern) then
							isIncluded = false
							break
						end
					end
				end

				if isIncluded and tostring(descendantPath):match(tostring(root)) then
					table.insert(watchedFolders, descendantPath)
				end
			end
		end
	end

	return watchedFolders
end

local function watch(options: Options)
	local watchers = {}
	local watcherToFolderMap = {}

	local watchedFolders = getWatchedFolders(options)

	print(richterm.dim("watching folders:"))
	for _, watchedFolder in watchedFolders do
		print(richterm.dim(`> {watchedFolder}`))

		local watcher = fs.watch(watchedFolder)

		watcherToFolderMap[watcher] = watchedFolder
		table.insert(watchers, watcher)
	end
	print("listening for file changes...")

	while true do
		for _, watcher in watchers do
			local event = watcher:next()
			local watchedFolder = watcherToFolderMap[watcher]

			if event and event.change and options.onChanged then
				options.onChanged(watchedFolder)
			end
		end
		task.wait(0.01)
	end
end

return watch
