--[[
	`PluginContextStore` aggregates contextual state about the user's
	current Studio session that's relevant to building an activity but
	is independent of the place being edited:

	- The currently-edited script
	- Whether the user is currently play testing

	The store is intended to run in the **edit** data model only.
	Guest plugin instances running in test data models use a separate
	lightweight entry path (`plugin/bin/setupGuest.luau`).
]]

local StudioService = game:GetService("StudioService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local Types = require(script.Parent.Types)
local createConnectionTracker = require(script.Parent.createConnectionTracker)

type ActiveScriptInfo = Types.ActiveScriptInfo
type StudioContext = Types.StudioContext
type TestPeer = Types.TestPeer

export type PluginContextStore = {
	getActiveScript: () -> ActiveScriptInfo?,
	getIsPlayTesting: () -> boolean,
	getTestPeers: () -> { [string]: TestPeer },
	getStudioContext: () -> StudioContext,
	destroy: () -> (),
}

local function snapshotActiveScript(script: Instance?): ActiveScriptInfo?
	if script == nil then
		return nil
	end

	local fullName: string
	local fullNameOk, fullNameResult = pcall(function()
		return script:GetFullName()
	end)
	if fullNameOk and typeof(fullNameResult) == "string" then
		fullName = fullNameResult
	else
		fullName = script.Name
	end

	return {
		name = script.Name,
		fullName = fullName,
		className = script.ClassName,
	}
end

local function createPluginContextStore(): PluginContextStore
	-- Active-script tracking

	local getActiveScript, setActiveScript = Charm.signal(snapshotActiveScript(StudioService.ActiveScript))

	local function refreshActiveScript()
		setActiveScript(snapshotActiveScript(StudioService.ActiveScript))
	end

	local activeScriptConnection = StudioService:GetPropertyChangedSignal("ActiveScript"):Connect(refreshActiveScript)

	-- Test-DM peer tracking

	local tracker = createConnectionTracker()

	local getIsPlayTesting = Charm.computed(function(): boolean
		return next(tracker.getPeers()) ~= nil
	end)

	local getStudioContext = Charm.computed(function(): StudioContext
		return {
			isPlayTesting = next(tracker.getPeers()) ~= nil,
			testPeers = tracker.getPeers(),
			activeScript = getActiveScript(),
		}
	end)

	local function destroy()
		if activeScriptConnection then
			activeScriptConnection:Disconnect()
		end

		tracker.destroy()
	end

	return {
		getActiveScript = getActiveScript,
		getIsPlayTesting = getIsPlayTesting,
		getTestPeers = tracker.getPeers,
		getStudioContext = getStudioContext,
		destroy = destroy,
	}
end

return createPluginContextStore
