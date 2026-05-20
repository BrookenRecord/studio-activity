local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)
local Sift = require(Packages.Sift)

local ProfileContext = require(script.Parent.Parent.ProfileContext)
local TemplateHint = require(script.Parent.TemplateHint)

local View = Foundation.View
local Dialog = Foundation.Dialog
local TextInput = Foundation.TextInput
local DialogSize = Foundation.Enums.DialogSize
local ButtonVariant = Foundation.Enums.ButtonVariant
local InputSize = Foundation.Enums.InputSize

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type CustomProfileData = ProfileContext.CustomProfileData
type CustomProfileStore = ProfileContext.CustomProfileStore

type Props = {
	profile: React.Binding<CustomProfileData>,
	store: CustomProfileStore,
	onClose: () -> (),
}

local function CustomProfileText(props: Props)
	local nextOrder = createNextOrder()

	return e(Dialog.Root, {
		size = DialogSize.Medium,
		hasBackdrop = true,
		disablePortal = false,
		onClose = function()
			props.onClose()
		end,
	}, {
		DialogTitle = e(Dialog.Title, {
			text = "Custom Text",
		}),

		DialogContent = e(Dialog.Content, nil, {
			Container = e(View, {
				tag = "size-full-0 auto-y col gap-large padding-xsmall padding-top-small",
				LayoutOrder = nextOrder(),
			}, {
				InputContainer = e(View, {
					tag = "size-full-0 auto-y col gap-medium",
					LayoutOrder = nextOrder(),
				}, {
					Details = e(TextInput, {
						text = props.profile:map(function(profile: CustomProfileData)
							return profile.activity.details or ""
						end),
						label = "Line 1",
						size = InputSize.Small,
						width = UDim.new(1, 0),
						LayoutOrder = nextOrder(),
						onChanged = function(text: string)
							props.store.setProfile(function(prev)
								return Sift.Dictionary.mergeDeep(prev, {
									activity = {
										details = if text == "" then Sift.None else text,
									},
								})
							end)
						end,
					}),

					State = e(TextInput, {
						text = props.profile:map(function(profile: CustomProfileData)
							return profile.activity.state or ""
						end),
						label = "Line 2",
						size = InputSize.Small,
						width = UDim.new(1, 0),
						LayoutOrder = nextOrder(),
						onChanged = function(text: string)
							props.store.setProfile(function(prev)
								return Sift.Dictionary.mergeDeep(prev, {
									activity = {
										state = if text == "" then Sift.None else text,
									},
								})
							end)
						end,
					}),
				}),

				TemplateHint = e(TemplateHint, {
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

return React.memo(CustomProfileText)
