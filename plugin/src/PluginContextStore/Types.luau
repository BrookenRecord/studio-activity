export type TestPeerRole = "server" | "client" | "unknown"

export type TestPeer = {
	targetId: string,
	role: TestPeerRole,
}

export type ActiveScriptInfo = {
	name: string,
	fullName: string,
	className: string,
}

export type StudioContext = {
	isPlayTesting: boolean,
	testPeers: { [string]: TestPeer },
	activeScript: ActiveScriptInfo?,
}

--[[
	Wire protocol between guest (test DM) and host (edit DM).

	The host treats the existence of a connected `PluginConnection` of type
	`Test` as the source of truth for "play testing is active". Messages
	enrich state (currently just the role) and provide forward-compatibility
	headroom.

	Unknown `kind` values are ignored on the receiver side.
]]
export type GuestMessage =
	{
		kind: "playtestStarted",
		role: TestPeerRole,
	}
	| {
		kind: "playtestStopped",
	}

return {}
