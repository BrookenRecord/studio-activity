--[[
	Lightweight entry point used when the plugin loads inside a play-test
	data model rather than the edit data model.

	Play Solo creates two test data models (one server, one client) that
	each receive their own copy of the plugin. We don't run the full UI,
	auth, or presence pipeline in those data models; we just open a
	`PluginConnection` to the edit data model and tell the host we're
	running, then sit quietly until the data model is torn down.

	The host treats the existence of any connected `PluginConnectionTargetType.Test`
	connection as "play testing", so messages here are best-effort
	enrichment (role: server/client) rather than load-bearing signals.
]]

local PluginConnectionService = game:GetService("PluginConnectionService")
local RunService = game:GetService("RunService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Logger = require(Plugin.Source.Logger)

local EDIT_TYPE = Enum.PluginConnectionTargetType.Edit

type Role = "server" | "client" | "unknown"

local function detectRole(): Role
	if RunService:IsServer() then
		return "server"
	elseif RunService:IsClient() then
		return "client"
	end
	return "unknown"
end

local function sendStarted(connection: PluginConnection, role: Role)
	if not connection.Connected then
		return
	end
	local ok, err = pcall(function()
		connection:SendMessage({
			kind = "playtestStarted",
			role = role,
		})
	end)
	if not ok then
		Logger:Warn(`setupGuest: failed to send playtestStarted: {tostring(err)}`)
	end
end

local function sendStopped(connection: PluginConnection)
	if not connection.Connected then
		return
	end
	pcall(function()
		connection:SendMessage({ kind = "playtestStopped" })
	end)
end

local function setupGuest(plugin: Plugin)
	plugin.Name = "StudioActivity"

	if not PluginConnectionService:CanHaveConnectionType(EDIT_TYPE) then
		Logger:Info("setupGuest: data model cannot have an Edit connection; skipping")
		return
	end

	local role: Role = detectRole()
	Logger:Info(`setupGuest: starting guest mode with role={role}`)

	-- Track all connections we've already announced ourselves to, so we don't
	-- double-send if the Connected event fires for the same connection.
	local announced: { [string]: PluginConnection } = {}

	local function announce(connection: PluginConnection)
		local targetId = connection.TargetId
		if announced[targetId] then
			return
		end
		announced[targetId] = connection
		sendStarted(connection, role)
	end

	-- Subscribe first so we don't miss any Edit connection that arrives
	-- between subscribe and enumerate.
	local connectedConn = PluginConnectionService.Connected:Connect(function(connection: PluginConnection)
		if connection.Type == EDIT_TYPE then
			announce(connection)
		end
	end)

	for _, existing in PluginConnectionService:GetPluginConnectionsOfType(EDIT_TYPE) do
		announce(existing)
	end

	plugin.Unloading:Connect(function()
		-- Best-effort stopped notification. The connection dropping is the
		-- canonical signal; this is just a hint that may arrive faster.
		for _, connection in announced do
			sendStopped(connection)
		end

		connectedConn:Disconnect()
		table.clear(announced)
	end)
end

return setupGuest
