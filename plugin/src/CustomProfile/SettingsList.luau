local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local ModalStore = require(Plugin.Source.Modal.ModalStore)
local ProfileContext = require(script.Parent.ProfileContext)

local View = Foundation.View
local List = Foundation.List
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName
local ListItemInputType = Foundation.Enums.ListItemInputType

local createNextOrder = ReactUtils.createNextOrder
local useSignalBinding = ReactCharm.useSignalBinding
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type CustomProfileData = ProfileContext.CustomProfileData

local function withDefault(value: boolean?, default: boolean): boolean
	return if value == nil then default else value
end

type Props = {
	LayoutOrder: number?,
}

local function SettingsList(props: Props)
	local nextOrder = createNextOrder()
	local profileStore = ProfileContext.useProfile().profileStore

	local currentProfile = useSignalState(profileStore.getProfile)
	local profileBinding = useSignalBinding(profileStore.getProfile)

	local showPlaceIcon = withDefault(currentProfile.activity.showPlaceIcon, true)
	local showJoinButton = withDefault(currentProfile.activity.showJoinButton, true)
	local showPluginButton = withDefault(currentProfile.activity.showPluginButton, false)

	return e(View, {
		tag = "size-full-0 auto-y",
		LayoutOrder = props.LayoutOrder,
	}, {
		List = e(List.Root, {
			hasDivider = true,
			isContained = { isContained = false :: false, hasMargin = false },
			size = InputSize.Small,
		}, {
			ActivityText = e(List.Item, {
				leading = IconName.TextUppercaseALowercaseA,
				title = "Custom text",
				description = "Edit the text shown on your activity.",
				onActivated = function()
					ModalStore.get().open("customProfileText", {
						props = {
							profile = profileBinding,
							store = profileStore,
						},
					})
				end,
				LayoutOrder = nextOrder(),
			}),

			GameOverride = e(List.Item, {
				leading = IconName.ControllerWithCog,
				title = "Game override",
				description = "Override the game displayed on your activity.",
				onActivated = function()
					ModalStore.get().open("customProfileGameOverride", {
						props = {
							store = profileStore,
						},
					})
				end,
				LayoutOrder = nextOrder(),
			}),

			GameIconToggle = e(List.Item, {
				leading = IconName.FrameCamera,
				title = "Show game icon",
				description = "Show the platform icon of the place you're currently editing.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							local current = withDefault(prev.activity.showPlaceIcon, true)
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

			JoinButtonToggle = e(List.Item, {
				leading = IconName.ChainLink,
				title = "Show play button",
				description = "Link the place you're currently editing with a 'Play on Roblox' button.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							local current = withDefault(prev.activity.showJoinButton, true)
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

			PluginButtonToggle = e(List.Item, {
				leading = IconName.Heart,
				title = "Show plugin button",
				description = "Support Studio Activity by linking it on your profile.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							local current = withDefault(prev.activity.showPluginButton, false)
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
	})
end

return React.memo(SettingsList)
