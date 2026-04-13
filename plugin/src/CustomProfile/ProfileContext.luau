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
local useContext = React.useContext

export type ProfileContext = {
	profileStore: CustomProfileStore,
}

local ProfileContext = React.createContext<<ProfileContext?>>(nil)
ProfileContext.displayName = "ProfileContext"

local function ProfileContextProvider(props: {
	existingProfileId: string?,
	children: React.ReactNode,
})
	local profileStore, setProfileStore = useState<<CustomProfileStore>>(function()
		-- We have to fill the state on first render
		return createCustomProfileStore(props.existingProfileId)
	end)

	useEffect(function()
		setProfileStore(createCustomProfileStore(props.existingProfileId))
	end, { props.existingProfileId })

	local value = useMemo(function(): ProfileContext
		return {
			profileStore = profileStore,
		}
	end)

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
