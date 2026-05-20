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
	local showCurrentScript = withDefault(currentProfile.activity.showCurrentScript, true)
	local showTestingState = withDefault(currentProfile.activity.showTestingState, true)

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
				description = "Set the lines of text shown in your activity.",
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
				description = "Show a specific game in your activity instead of the one you're editing.",
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
				description = "Display the icon of the game you're editing.",
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
				description = "Add a 'Play on Roblox' button that links to your game.",
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

			ShowScriptToggle = e(List.Item, {
				leading = IconName.ChainLink,
				title = "Show current script",
				description = "Display the name of the script you're editing.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							local current = withDefault(prev.activity.showCurrentScript, true)
							return Sift.Dictionary.mergeDeep(prev, {
								activity = {
									showCurrentScript = not current,
								},
							})
						end)
					end,
					inputType = ListItemInputType.Toggle,
					isChecked = showCurrentScript,
				},
				LayoutOrder = nextOrder(),
			}),

			ShowTestingToggle = e(List.Item, {
				leading = IconName.ChainLink,
				title = "Show testing mode",
				description = "Indicate when you're playtesting your game.",
				onActivated = {
					onActivated = function()
						profileStore.setProfile(function(prev)
							local current = withDefault(prev.activity.showTestingState, true)
							return Sift.Dictionary.mergeDeep(prev, {
								activity = {
									showTestingState = not current,
								},
							})
						end)
					end,
					inputType = ListItemInputType.Toggle,
					isChecked = showTestingState,
				},
				LayoutOrder = nextOrder(),
			}),

			PluginButtonToggle = e(List.Item, {
				leading = IconName.Heart,
				title = "Show plugin button",
				description = "Add a button that links others to the Studio Activity plugin.",
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
