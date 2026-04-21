local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local ProfileContext = require(script.Parent.ProfileContext)
local Section = require(Plugin.Source.Common.Section)

local View = Foundation.View
local Checkbox = Foundation.Checkbox
local TextInput = Foundation.TextInput
local InputSize = Foundation.Enums.InputSize

local createNextOrder = ReactUtils.createNextOrder
local useSignalBinding = ReactCharm.useSignalBinding
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type CustomProfileData = ProfileContext.CustomProfileData

type Props = {
	LayoutOrder: number?,
}

local function ActivityFields(props: Props)
	local nextOrder = createNextOrder()
	local profileStore = ProfileContext.useProfile().profileStore

	local profileBinding = useSignalBinding(profileStore.getProfile)
	local showPlaceIcon = useSignalState(Charm.computed(function() end))

	return e(Section, {
		title = "Activity Fields",
		canToggleExpand = true,
		hasDivider = true,
		LayoutOrder = props.LayoutOrder,
	}, {
		LayoutBlock = e(View, {
			tag = "size-full-0 auto-y col gap-medium",
			LayoutOrder = nextOrder(),
		}, {
			GameIconToggle = e(Checkbox, {
				label = "Show game icon",
				isChecked = showPlaceIcon,
				size = InputSize.Small,
				LayoutOrder = nextOrder(),
				onActivated = function()
					profileStore.setProfile(function(prev)
						return Sift.Dictionary.mergeDeep(prev, {
							activity = {
								showPlaceIcon = not showPlaceIcon,
							},
						})
					end)
				end,
			}),

			Details = e(TextInput, {
				text = profileBinding:map(function(profile: CustomProfileData)
					return profile.activity.details or ""
				end),
				label = "Line 1",
				size = InputSize.Small,
				width = UDim.new(1, 0),
				LayoutOrder = nextOrder(),
				onChanged = function(text: string)
					profileStore.setProfile(function(prev)
						return Sift.Dictionary.mergeDeep(prev, {
							activity = {
								details = if text == "" then Sift.None else text,
							},
						})
					end)
				end,
			}),

			State = e(TextInput, {
				text = profileBinding:map(function(profile: CustomProfileData)
					return profile.activity.state or ""
				end),
				label = "Line 2",
				size = InputSize.Small,
				width = UDim.new(1, 0),
				LayoutOrder = nextOrder(),
				onChanged = function(text: string)
					profileStore.setProfile(function(prev)
						return Sift.Dictionary.mergeDeep(prev, {
							activity = {
								state = if text == "" then Sift.None else text,
							},
						})
					end)
				end,
			}),
		}),
	})
end

return React.memo(ActivityFields)
