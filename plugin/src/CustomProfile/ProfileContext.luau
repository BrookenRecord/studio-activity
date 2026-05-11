local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local createCustomProfileStore = require(script.Parent.createCustomProfileStore)
export type CustomProfileStore = createCustomProfileStore.CustomProfileStore
export type CustomProfileData = createCustomProfileStore.CustomProfileData

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useContext = React.useContext

export type ProfileContext = {
	profileStore: CustomProfileStore,
}

local ProfileContext = React.createContext<<ProfileContext?>>(nil)
ProfileContext.displayName = "ProfileContext"

local function ProfileContextProvider(props: {
	isOpen: boolean,
	existingProfileId: string?,
	children: React.ReactNode,
})
	local profileStore, setProfileStore = useState<<CustomProfileStore>>(function()
		-- We have to fill the state on first render
		return createCustomProfileStore(props.existingProfileId)
	end)

	-- Track the most recently committed store so we can dispose of it before
	-- swapping in a new one, even across the React render/commit boundary.
	local activeStoreRef = useRef(profileStore)
	-- Track whether the sheet was previously open so we can recreate the store
	-- only on a closed -> open transition, not on every prop change.
	local prevIsOpenRef = useRef(props.isOpen)

	useEffect(function()
		local isOpening = props.isOpen and not prevIsOpenRef.current
		prevIsOpenRef.current = props.isOpen

		if not isOpening then
			return
		end

		local nextStore = createCustomProfileStore(props.existingProfileId)
		local previousStore = activeStoreRef.current
		activeStoreRef.current = nextStore
		setProfileStore(nextStore)

		if previousStore and previousStore ~= nextStore then
			previousStore.destroy()
		end
	end, { props.isOpen :: any, props.existingProfileId })

	useEffect(function()
		return function()
			local store = activeStoreRef.current
			if store then
				store.destroy()
				activeStoreRef.current = nil :: any
			end
		end
	end, {})

	local value = useMemo(function(): ProfileContext
		return {
			profileStore = profileStore,
		}
	end, { profileStore })

	return e(ProfileContext.Provider, {
		value = value,
	}, props.children)
end

local function useProfile(): ProfileContext
	local context = useContext(ProfileContext)
	if context == nil then
		error("useProfile must be used within a ProfileContextProvider")
	end
	return context
end

return {
	Context = ProfileContextProvider,
	Provider = ProfileContextProvider,
	useProfile = useProfile,
}
