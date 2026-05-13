local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local ProfileContext = require(script.Parent.ProfileContext)
local Section = require(Plugin.Source.Common.Section)

local TextInput = Foundation.TextInput
local InputSize = Foundation.Enums.InputSize

local createNextOrder = ReactUtils.createNextOrder
local useSignalBinding = ReactCharm.useSignalBinding

local e = React.createElement

type CustomProfileData = ProfileContext.CustomProfileData

type Props = {
	LayoutOrder: number?,
}

local function ProfileName(props: Props)
	local nextOrder = createNextOrder()
	local profileStore = ProfileContext.useProfile().profileStore
	local profileBinding = useSignalBinding(profileStore.getProfile)

	return e(Section, {
		canToggleExpand = false,
		hasDivider = true,
		LayoutOrder = props.LayoutOrder,
	}, {
		ProfileName = e(TextInput, {
			text = profileBinding:map(function(profile: CustomProfileData)
				return profile.name
			end),
			label = "Profile Name",
			size = InputSize.Small,
			width = UDim.new(1, 0),
			LayoutOrder = nextOrder(),
			onChanged = function(text: string)
				profileStore.setProfile(function(prev)
					return Sift.Dictionary.mergeDeep(prev, {
						name = text,
					})
				end)
			end,
		}),
	})
end

return ProfileName
