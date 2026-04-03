local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local React = require(Packages.React)

local BuildVars = require(Plugin.Source.BuildVars)

local DeviceCodeFlow = require(Plugin.Source.Authentication.Flows.DeviceCodeFlow)
type DeviceCodeFlow = DeviceCodeFlow.DeviceCodeFlow
type Status = DeviceCodeFlow.Status

local e = React.createElement
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState
local useEffect = React.useEffect
local useContext = React.useContext

export type AuthContext = {
	deviceCodeFlow: DeviceCodeFlow,
}

local AuthContext = React.createContext<<AuthContext?>>(nil)
AuthContext.displayName = "AuthContext"

local function AuthContextProvider(props: {
	onClose: () -> (),
	children: React.ReactNode,
}): React.ReactNode
	local flowRef = useRef<<DeviceCodeFlow?>>(nil)
	local deviceCodeFlow, setDeviceCodeFlow = useState<<DeviceCodeFlow?>>(nil)

	useEffect(function()
		-- Strict Mode calls this twice, but the ref guard
		-- ensures we only start one flow.
		if flowRef.current ~= nil then
			return
		end

		local flow = DeviceCodeFlow.create({
			httpService = HttpService,
			clientId = BuildVars.discord.clientId,
		})

		task.spawn(function()
			flow.requestAsync()
		end)

		flowRef.current = flow
		setDeviceCodeFlow(flow)

		-- Listen for when the status changes and close the sheet when it does.
		local dispose = Charm.effect(function()
			local status: Status = flow.status() :: Status

			-- TODO: Handle other new status cases
			if status == "authorized" then
				props.onClose()
			end
		end)

		return function()
			dispose()

			-- Only runs on real unmount. In Strict Mode, the first
			-- unmount is simulated — but since we ref-guarded the
			-- creation, cleanup here is a no-op on the second mount.
			if flowRef.current == flow then
				flow.destroy()
				flowRef.current = nil
			end
		end
	end, {})

	local value = useMemo(function(): AuthContext
		return {
			deviceCodeFlow = deviceCodeFlow :: DeviceCodeFlow,
		}
	end, { deviceCodeFlow })

	-- Don't render children until we have the state
	if deviceCodeFlow == nil then
		return nil
	end

	return e(AuthContext.Provider, {
		value = value,
	}, props.children)
end

local function useAuth(): AuthContext
	local context = useContext(AuthContext)
	if context == nil then
		error("useAuth must be used from within an AuthContextProvider")
	end
	return context
end

return {
	Context = AuthContext,
	Provider = AuthContextProvider,
	useAuth = useAuth,
}
