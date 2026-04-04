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

local function TelemetryOptOutDialog(props: Props)
	local nextOrder = createNextOrder()

	local userSettingsStore = UserSettingsStore.get()
	local localStorageStore = LocalStorageStore.get()

	local isOptedIn, setIsOptedIn = useState(true)

	local onClose = useCallback(function()
		-- Fire the event before writing the setting so the opt-out event
		-- isn't blocked by the collectAnonymousUsageData check.
		if isOptedIn then
			fireEvent({ eventName = "TelemetryOptedIn" })
		else
			fireEvent({ eventName = "TelemetryOptedOut" })
		end

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

		props.onClose()
	end, { localStorageStore.setStorage :: any, userSettingsStore.setStorage, isOptedIn, props.onClose })

	local onCancel = useCallback(function()
		localStorageStore.setStorage(function(prev)
			return Sift.Dictionary.join(prev, {
				wasUserPromptedForTelemetry = true,
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
