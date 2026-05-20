local Plugin = script:FindFirstAncestor("StudioActivity")

local Types = require(script.Types)
local createPluginContextStore = require(script.createPluginContextStore)
local createSingleton = require(Plugin.Source.Common.createSingleton)

export type ActiveScriptInfo = Types.ActiveScriptInfo
export type TestPeer = Types.TestPeer
export type TestPeerRole = Types.TestPeerRole
export type StudioContext = Types.StudioContext
export type GuestMessage = Types.GuestMessage
export type PluginContextStore = createPluginContextStore.PluginContextStore

return table.freeze({
	get = createSingleton(function(): createPluginContextStore.PluginContextStore
		return createPluginContextStore()
	end),
})
