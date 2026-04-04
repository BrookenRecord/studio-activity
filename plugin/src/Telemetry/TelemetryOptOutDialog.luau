local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)
local fireEventAsync = require(script.Parent.fireEventAsync)

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

local function TelemetryOptOutDialog(props: Props)
	local nextOrder = createNextOrder()

	local userSettingsStore = UserSettingsStore.get()
	local localStorageStore = LocalStorageStore.get()

	local isOptedIn, setIsOptedIn = useState(true)

	local onClose = useCallback(function()
		localStorageStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				wasUserPromptedForTelemetry = true,
			})
		end)

		userSettingsStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				collectAnonymousUsageData = isOptedIn,
			})
		end)

		task.spawn(function()
			if isOptedIn then
				fireEventAsync({
					eventName = "TelemetryOptedIn",
				})
			else
				fireEventAsync({
					eventName = "TelemetryOptedOut",
				})
			end
		end)

		props.onClose()
	end, { localStorageStore.setStorage :: any, userSettingsStore.setStorage, isOptedIn, props.onClose })

	return React.createElement(Dialog.Root, {
		disablePortal = false,
		hasBackdrop = true,
		onClose = onClose,
		onPressedOutside = onClose,
	}, {
		Title = React.createElement(Dialog.Title, {
			text = "Help us improve the plugin",
		}),

		Content = React.createElement(Dialog.Content, {
			LayoutOrder = nextOrder(),
		}, {
			Wrapper = React.createElement(View, {
				tag = "auto-xy col gap-large",
			}, {
				MainParagraph = React.createElement(Dialog.Text, {
					tag = "auto-xy text-wrap text-body-medium",
					Text = "Studio Rich Presence would like to send anonymized usage data to help us improve the quality of the plugin.",
					LayoutOrder = nextOrder(),
				}),

				WhereToOptOut = React.createElement(Dialog.Text, {
					tag = "auto-xy text-wrap text-body-medium",
					Text = "You can opt out at any time in the settings.",
					LayoutOrder = nextOrder(),
				}),

				Checkbox = React.createElement(Checkbox, {
					label = "Help improve the plugin by sending anonymous usage data",
					isChecked = isOptedIn,
					onActivated = setIsOptedIn,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),

		Actions = React.createElement(Dialog.Actions, {
			actions = {
				{
					text = "Done",
					variant = ButtonVariant.Emphasis,
					onActivated = onClose,
				},
			},
			LayoutOrder = nextOrder(),
		}),
	})
end

return TelemetryOptOutDialog
