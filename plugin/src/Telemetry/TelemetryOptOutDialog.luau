local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)
local fireEvent = require(script.Parent.fireEventAsync)

local View = Foundation.View
local Dialog = Foundation.Dialog
local Checkbox = Foundation.Checkbox
local ButtonVariant = Foundation.Enums.ButtonVariant

local createNextOrder = ReactUtils.createNextOrder
local useCallback = React.useCallback
local useState = React.useState

type Props = {
	onClose: (result: any?) -> (),
}

local function WelcomeDialog(props: Props)
	local nextOrder = createNextOrder()

	local userSettingsStore = UserSettingsStore.get()
	local localStorageStore = LocalStorageStore.get()

	local isOptedIn, setIsOptedIn = useState(true)

	local onClose = useCallback(function()
		if isOptedIn then
			fireEvent({ eventName = "TelemetryOptedIn" })
		else
			fireEvent({ eventName = "TelemetryOptedOut" })
		end

		localStorageStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				hasCompletedOnboarding = true,
			})
		end)

		userSettingsStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				collectAnonymousUsageData = isOptedIn,
			})
		end)

		props.onClose()
	end, { localStorageStore.setStorage :: any, userSettingsStore.setStorage, isOptedIn, props.onClose })

	local onCancel = useCallback(function()
		localStorageStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				hasCompletedOnboarding = true,
			})
		end)
		props.onClose()
	end, { localStorageStore.setStorage :: any, props.onClose })

	return React.createElement(Dialog.Root, {
		disablePortal = false,
		hasBackdrop = true,
		onClose = onCancel,
		onPressedOutside = onCancel,
	}, {
		Title = React.createElement(Dialog.Title, {
			text = "Welcome to Studio Activity",
		}),

		Content = React.createElement(Dialog.Content, {
			LayoutOrder = nextOrder(),
		}, {
			Wrapper = React.createElement(View, {
				tag = "auto-xy col gap-large",
			}, {
				WelcomeParagraph = React.createElement(Dialog.Text, {
					tag = "auto-xy text-wrap text-body-medium",
					Text = "Studio Activity lets you show what you're working on in Roblox Studio as your Discord status. Link your Discord account to get started!",
					LayoutOrder = nextOrder(),
				}),

				TelemetryParagraph = React.createElement(Dialog.Text, {
					tag = "auto-xy text-wrap text-body-medium",
					Text = "This is a plugin built by one person. Anonymous usage data helps me understand how many people use it and where things break. You can change this anytime in settings.",
					LayoutOrder = nextOrder(),
				}),

				Checkbox = React.createElement(Checkbox, {
					label = "Help out by sending anonymous usage data",
					isChecked = isOptedIn,
					onActivated = setIsOptedIn,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),

		Actions = React.createElement(Dialog.Actions, {
			actions = {
				{
					text = "Get Started",
					variant = ButtonVariant.Emphasis,
					onActivated = onClose,
				},
			},
			LayoutOrder = nextOrder(),
		}),
	})
end

return WelcomeDialog
