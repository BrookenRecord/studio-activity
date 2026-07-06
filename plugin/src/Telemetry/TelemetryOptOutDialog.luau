local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local Telemetry = require(script.Parent.fireEventAsync)
local Types = require(script.Parent.Types)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)

local View = Foundation.View
local Dialog = Foundation.Dialog
local Checkbox = Foundation.Checkbox
local ButtonVariant = Foundation.Enums.ButtonVariant

local createNextOrder = ReactUtils.createNextOrder
local useCallback = React.useCallback
local useEffect = React.useEffect
local useState = React.useState
local useSignalState = ReactCharm.useSignalState

type Props = {
	onClose: (result: any?) -> (),
}

local function WelcomeDialog(props: Props)
	local nextOrder = createNextOrder()

	local userSettingsStore = UserSettingsStore.get()
	local localStorageStore = LocalStorageStore.get()
	local userSettings = useSignalState(userSettingsStore.getStorage)
	local isUserSettingsLoading = useSignalState(userSettingsStore.getIsLoading)
	local isLocalStorageLoading = useSignalState(localStorageStore.getIsLoading)
	local isLoading = isUserSettingsLoading or isLocalStorageLoading

	local isOptedIn, setIsOptedIn = useState(true)

	useEffect(function()
		if not isUserSettingsLoading then
			setIsOptedIn(userSettings.collectAnonymousUsageData)
		end
	end, { isUserSettingsLoading, userSettings.collectAnonymousUsageData })

	local onClose = useCallback(function()
		if isLoading then
			return
		end

		userSettingsStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				collectAnonymousUsageData = isOptedIn,
			})
		end)

		localStorageStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				hasCompletedOnboarding = true,
			})
		end)

		if isOptedIn then
			Telemetry.fireEvent({
				type = "onboardingCompleted",
				value = Types.OnboardingCompleted.new({ optedIntoTelemetry = true }),
			})
		end

		props.onClose()
	end, { isLoading, isOptedIn })

	local onCancel = useCallback(function()
		props.onClose()
	end, { props.onClose })

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
					onActivated = if isLoading then function() end else setIsOptedIn,
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
