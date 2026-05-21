local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local OverridePreview = require(script.Parent.OverridePreview)
local ProfileContext = require(script.Parent.Parent.ProfileContext)

local View = Foundation.View
local Dialog = Foundation.Dialog
local NumberInput = Foundation.NumberInput
local DialogSize = Foundation.Enums.DialogSize
local InputSize = Foundation.Enums.InputSize
local ButtonVariant = Foundation.Enums.ButtonVariant
local OnChangeCallbackReason = Foundation.Enums.OnChangeCallbackReason
local NumberInputControlsVariant = Foundation.Enums.NumberInputControlsVariant

type OnChangeCallbackReason = Foundation.OnChangeCallbackReason
type CustomProfileStore = ProfileContext.CustomProfileStore

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	store: CustomProfileStore,
	onClose: () -> (),
}

local function CustomProfileGameOverride(props: Props)
	local nextOrder = createNextOrder()

	local override = useSignalState(props.store.getOverrideLookupState)

	return e(Dialog.Root, {
		size = DialogSize.Medium,
		hasBackdrop = true,
		disablePortal = false,
		onClose = function()
			props.onClose()
		end,
	}, {
		DialogTitle = e(Dialog.Title, {
			text = "Game Override",
		}),

		DialogContent = e(Dialog.Content, nil, {
			LayoutBlock = e(View, {
				tag = "size-full-0 auto-y col gap-medium padding-xsmall",
				LayoutOrder = nextOrder(),
			}, {
				PlaceIdInput = e(NumberInput, {
					label = "Place ID",
					hint = "Show a specific game in your activity. Leave blank to use the place you're editing.",
					value = override.placeId or 0,
					onChanged = function(placeId: number, reason: OnChangeCallbackReason)
						-- NumberInput re-fires onChanged with its `value` prop on focus loss.
						-- While our lookup debounce is in flight `value` collapses to 0,
						-- which would normalise to "" and wipe the override. Keyboard
						-- events already capture every real edit, so we can safely
						-- ignore FocusLost.
						if reason == OnChangeCallbackReason.FocusLost then
							return
						end
						props.store.setOverrideLookupInput(if placeId == 0 then "" else tostring(placeId))
					end,
					formatAsString = function(placeId: number)
						return if override.status == "loading"
							then "Loading..."
							elseif placeId == 0 then "None"
							else tostring(placeId)
					end,
					controlsVariant = NumberInputControlsVariant.None,
					size = InputSize.Small,
					width = UDim.new(1, 0),
					LayoutOrder = nextOrder(),
				}),

				OverridePreview = e(OverridePreview, {
					store = props.store,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),

		DialogActions = e(Dialog.Actions, {
			actions = {
				{
					text = "Save",
					variant = ButtonVariant.Emphasis,
					onActivated = function()
						props.onClose()
					end,
				},
			},
		}),
	})
end

return React.memo(CustomProfileGameOverride)
