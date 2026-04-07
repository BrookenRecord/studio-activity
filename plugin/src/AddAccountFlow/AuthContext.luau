local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local React = require(Packages.React)

local BackendApi = require(Plugin.Source.Api.Backend)
local BuildVars = require(Plugin.Source.BuildVars)
local DiscordApi = require(Plugin.Source.Api.Discord)

local BrowserCodeFlow = require(Plugin.Source.Authentication.Flows.BrowserCodeFlow)
local DeviceCodeFlow = require(Plugin.Source.Authentication.Flows.DeviceCodeFlow)
type BrowserCodeFlow = BrowserCodeFlow.BrowserCodeFlow
type DeviceCodeFlow = DeviceCodeFlow.DeviceCodeFlow

local e = React.createElement
local useRef = React.useRef
local useEffect = React.useEffect
local useContext = React.useContext

export type AuthContext = {
	deviceCodeFlow: DeviceCodeFlow,
	browserCodeFlow: BrowserCodeFlow,
}

local AuthContext = React.createContext<<AuthContext?>>(nil)
AuthContext.displayName = "AuthContext"

-- Construct fresh flow instances. Cheap (just signals + closures) — the
-- network calls only start once `requestAsync` is invoked from the effect.
local function createFlows(): AuthContext
	local discord = DiscordApi.new({
		clientId = BuildVars.discord.clientId,
	})
	local backend = BackendApi.new(BuildVars.api)

	return {
		deviceCodeFlow = DeviceCodeFlow.create({ discord = discord }),
		browserCodeFlow = BrowserCodeFlow.create({ discord = discord, backend = backend }),
	}
end

local function AuthContextProvider(props: {
	onClose: () -> (),
	children: React.ReactNode,
}): React.ReactNode
	-- Lazy ref init: build the flows exactly once per real component
	-- lifetime. The ref keeps the same object across re-renders, and a
	-- fresh component instance gets a fresh ref, so we never leak flows
	-- and never observe nil during render.
	local flowsRef = useRef<<AuthContext?>>(nil)
	if flowsRef.current == nil then
		flowsRef.current = createFlows()
	end
	local flows = flowsRef.current :: AuthContext

	useEffect(function()
		flows.deviceCodeFlow.requestAsync()
		flows.browserCodeFlow.requestAsync()

		-- Close the sheet as soon as either flow authorizes.
		local dispose = Charm.effect(function()
			local deviceStatus: DeviceCodeFlow.Status = flows.deviceCodeFlow.status() :: DeviceCodeFlow.Status
			local browserStatus: BrowserCodeFlow.Status = flows.browserCodeFlow.status() :: BrowserCodeFlow.Status

			if deviceStatus == "authorized" or browserStatus == "authorized" then
				props.onClose()
			end
		end)

		return function()
			dispose()
			-- destroy() cancels in-flight polling and resets each flow
			-- to "idle" without freeing the object. Strict Mode's
			-- simulated unmount→remount will simply re-`requestAsync`
			-- on the same instances, which is exactly the behavior we
			-- want for a real "user reopens the sheet" cycle too.
			flows.deviceCodeFlow.destroy()
			flows.browserCodeFlow.destroy()
		end
	end, {})

	return e(AuthContext.Provider, {
		value = flows,
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
