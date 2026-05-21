local PluginConnectionService = game:GetService("PluginConnectionService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local Logger = require(Plugin.Source.Logger)
local Types = require(script.Parent.Types)

type TestPeer = Types.TestPeer
type TestPeerRole = Types.TestPeerRole

export type ConnectionTracker = {
	getPeers: () -> { [string]: TestPeer },
	destroy: () -> (),
}

local function parseRole(value: any): TestPeerRole
	if value == "server" or value == "client" then
		return value :: TestPeerRole
	end
	return "unknown"
end

local function createConnectionTracker(): ConnectionTracker
	local getPeers, setPeers = Charm.signal<<{ [string]: TestPeer }>>({})

	local connections: { RBXScriptConnection } = {}

	-- Keyed by TargetId; tracks per-connection disposers so we can clean up if a
	-- single connection drops without nuking the whole tracker
	local perConnectionDisposers: { [string]: { RBXScriptConnection } } = {}

	local destroyed = false

	local function disconnectAll(list: { RBXScriptConnection })
		for _, rbxConn in list do
			rbxConn:Disconnect()
		end
		table.clear(list)
	end

	local function removePeer(targetId: string)
		setPeers(function(prev)
			if prev[targetId] == nil then
				return prev
			end
			local new = table.clone(prev)
			new[targetId] = nil
			return new
		end)

		local disposers = perConnectionDisposers[targetId]
		if disposers then
			perConnectionDisposers[targetId] = nil
			disconnectAll(disposers)
		end
	end

	local function upsertPeer(targetId: string, role: TestPeerRole)
		setPeers(function(prev)
			local existing = prev[targetId]
			-- Don't downgrade a known role back to "unknown"
			local nextRole: TestPeerRole = if role == "unknown"
					and existing
					and existing.role ~= "unknown"
				then existing.role
				else role

			if existing and existing.role == nextRole then
				return prev
			end

			local new = table.clone(prev)
			new[targetId] = {
				targetId = targetId,
				role = nextRole,
			}
			return new
		end)
	end

	local function registerConnection(connection: PluginConnection)
		if destroyed then
			return
		end

		local targetId = connection.TargetId

		-- A connection may already be disconnected by the time we observe it
		-- (rare race between enumeration and registration). Skip it.
		if not connection.Connected then
			return
		end

		-- Avoid double-registering on the same TargetId
		if perConnectionDisposers[targetId] then
			return
		end

		local disposers: { RBXScriptConnection } = {}
		perConnectionDisposers[targetId] = disposers

		upsertPeer(targetId, "unknown")

		local messageOk, messageBinding = pcall(function()
			return connection:BindToMessage(function(message: any)
				if typeof(message) ~= "table" then
					return
				end

				local kind = message.kind
				if kind == "playtestStarted" then
					upsertPeer(targetId, parseRole(message.role))
				elseif kind == "playtestStopped" then
					-- Connection drop is canonical; treat explicit stop as a
					-- hint and still wait for `Connected` to flip. Some guests
					-- may send this best-effort right before unload.
					removePeer(targetId)
				else
					Logger:Info(`PluginContextStore: ignored unknown guest message kind={tostring(kind)}`)
				end
			end)
		end)

		if messageOk and messageBinding then
			table.insert(disposers, messageBinding)
		else
			Logger:Warn(`PluginContextStore: failed to bind message handler for {targetId}: {tostring(messageBinding)}`)
		end

		local propOk, propSignal = pcall(function()
			return connection:GetPropertyChangedSignal("Connected")
		end)

		if propOk and propSignal then
			local rbxConn = propSignal:Connect(function()
				if not connection.Connected then
					removePeer(targetId)
				end
			end)
			table.insert(disposers, rbxConn)
		else
			Logger:Warn(`PluginContextStore: failed to subscribe Connected for {targetId}: {tostring(propSignal)}`)
		end

		-- Re-check Connected after we've registered. If it became false between
		-- the initial check and now, we still want to drop the peer.
		if not connection.Connected then
			removePeer(targetId)
		end
	end

	--[[
		Subscribe to new connections first so nothing that arrives between
		"subscribe" and "enumerate" is missed. Pre-existing connections are
		then enumerated and registered (registration is idempotent).
	]]
	local addedConn = PluginConnectionService.Connected:Connect(function(newConnection)
		registerConnection(newConnection)
	end)
	table.insert(connections, addedConn)

	for _, existingConnection in
		PluginConnectionService:GetPluginConnectionsOfType(Enum.PluginConnectionTargetType.Test)
	do
		registerConnection(existingConnection)
	end

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true

		disconnectAll(connections)

		for targetId, disposers in perConnectionDisposers do
			disconnectAll(disposers)
			perConnectionDisposers[targetId] = nil
		end

		setPeers({})
	end

	return {
		getPeers = getPeers,
		destroy = destroy,
	}
end

return createConnectionTracker
