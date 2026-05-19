local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local ProfileContext = require(script.Parent.ProfileContext)

local View = Foundation.View
local List = Foundation.List
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName
local ListItemInputType = Foundation.Enums.ListItemInputType

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type CustomProfileData = ProfileContext.CustomProfileData

type Props = {
	LayoutOrder: number?,
}

local function ActivityFields(props: Props)
	local nextOrder = createNextOrder()
	local profileStore = ProfileContext.useProfile().profileStore

	local currentProfile = useSignalState(profileStore.getProfile)
	-- local profileBinding = useSignalBinding(profileStore.getProfile)

	local showPlaceIcon = if currentProfile.activity.showPlaceIcon == nil
		then true
		else currentProfile.activity.showPlaceIcon
	local showJoinButton = if currentProfile.activity.showJoinButton == nil
		then true
		else currentProfile.activity.showJoinButton
	local showPluginButton = if currentProfile.activity.showPluginButton == nil
		then false
		else currentProfile.activity.showPluginButton

	return e(View, {
		tag = "size-full-0 auto-y",
		LayoutOrder = props.LayoutOrder,
	}, {
		List = e(List.Root, {
			hasDivider = true,
			isContained = { isContained = false :: false, hasMargin = false },
			size = InputSize.Small,
		}, {
			ActivityText = React.createElement(List.Item, {
				leading = IconName.TextUppercaseALowercaseA,
				title = "Custom text",
				description = "Edit the text shown on your activity.",
				onActivated = function() end,
				LayoutOrder = nextOrder(),
			}),

			GameOverride = React.createElement(List.Item, {
				leading = IconName.ControllerWithCog,
				title = "Game override",
				description = "Override the game displayed on your activity.",
				onActivated = function() end,
				LayoutOrder = nextOrder(),
			}),

			GameIconToggle = React.createElement(List.Item, {
				leading = IconName.FrameCamera,
				title = "Show game icon",
				description = "Show the platform icon of the place you're currently editing.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							-- Read from `prev` so concurrent updates don't desync; treat
							-- the absence of an explicit value as the default (true).
							local current = if prev.activity.showPlaceIcon == nil
								then true
								else prev.activity.showPlaceIcon
							return Sift.Dictionary.mergeDeep(prev, {
								activity = {
									showPlaceIcon = not current,
								},
							})
						end)
					end,
					inputType = ListItemInputType.Toggle,
					isChecked = showPlaceIcon,
				},
				LayoutOrder = nextOrder(),
			}),

			JoinButtonToggle = React.createElement(List.Item, {
				leading = IconName.ChainLink,
				title = "Show play button",
				description = "Link the place you're currently editing with a 'Play on Roblox' button.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							-- Read from `prev` so concurrent updates don't desync; treat
							-- the absence of an explicit value as the default (true).
							local current = if prev.activity.showJoinButton == nil
								then true
								else prev.activity.showJoinButton
							return Sift.Dictionary.mergeDeep(prev, {
								activity = {
									showJoinButton = not current,
								},
							})
						end)
					end,
					inputType = ListItemInputType.Toggle,
					isChecked = showJoinButton,
				},
				LayoutOrder = nextOrder(),
			}),

			PluginButtonToggle = React.createElement(List.Item, {
				leading = IconName.Heart,
				title = "Show plugin button",
				description = "Support Studio Activity by linking it on your profile.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							-- Read from `prev` so concurrent updates don't desync; treat
							-- the absence of an explicit value as the default (true).
							local current = if prev.activity.showPluginButton == nil
								then false
								else prev.activity.showPluginButton
							return Sift.Dictionary.mergeDeep(prev, {
								activity = {
									showPluginButton = not current,
								},
							})
						end)
					end,
					inputType = ListItemInputType.Toggle,
					isChecked = showPluginButton,
				},
				LayoutOrder = nextOrder(),
			}),
		}),

		-- GameIconToggle = e(Checkbox, {
		-- 	label = "Show game icon",
		-- 	isChecked = showPlaceIcon,
		-- 	size = InputSize.Small,
		-- 	LayoutOrder = nextOrder(),
		-- 	onActivated = function()
		-- 		profileStore.setProfile(function(prev)
		-- 			-- Read from `prev` so concurrent updates don't desync; treat
		-- 			-- the absence of an explicit value as the default (true).
		-- 			local current = if prev.activity.showPlaceIcon == nil then true else prev.activity.showPlaceIcon
		-- 			return Sift.Dictionary.mergeDeep(prev, {
		-- 				activity = {
		-- 					showPlaceIcon = not current,
		-- 				},
		-- 			})
		-- 		end)
		-- 	end,
		-- }),

		-- Details = e(TextInput, {
		-- 	text = profileBinding:map(function(profile: CustomProfileData)
		-- 		return profile.activity.details or ""
		-- 	end),
		-- 	label = "Line 1",
		-- 	size = InputSize.Small,
		-- 	width = UDim.new(1, 0),
		-- 	LayoutOrder = nextOrder(),
		-- 	onChanged = function(text: string)
		-- 		profileStore.setProfile(function(prev)
		-- 			return Sift.Dictionary.mergeDeep(prev, {
		-- 				activity = {
		-- 					details = if text == "" then Sift.None else text,
		-- 				},
		-- 			})
		-- 		end)
		-- 	end,
		-- }),

		-- State = e(TextInput, {
		-- 	text = profileBinding:map(function(profile: CustomProfileData)
		-- 		return profile.activity.state or ""
		-- 	end),
		-- 	label = "Line 2",
		-- 	size = InputSize.Small,
		-- 	width = UDim.new(1, 0),
		-- 	LayoutOrder = nextOrder(),
		-- 	onChanged = function(text: string)
		-- 		profileStore.setProfile(function(prev)
		-- 			return Sift.Dictionary.mergeDeep(prev, {
		-- 				activity = {
		-- 					state = if text == "" then Sift.None else text,
		-- 				},
		-- 			})
		-- 		end)
		-- 	end,
		-- }),
	})
end

return React.memo(ActivityFields)
