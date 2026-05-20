local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local Dialog = Foundation.Dialog
local DialogSize = Foundation.Enums.DialogSize
local ButtonVariant = Foundation.Enums.ButtonVariant

local e = React.createElement

type Props = {
	title: string?,
	body: string?,
	onClose: (result: boolean) -> (),
}

local function ConfirmationDialog(props: Props)
	return e(Dialog.Root, {
		size = DialogSize.Small,
		hasBackdrop = true,
		disablePortal = false,
		onClose = function()
			props.onClose(false)
		end,
	}, {
		DialogTitle = e(Dialog.Title, {
			text = props.title or "Confirm Action",
		}),
		DialogContent = e(Dialog.Content, nil, {
			DialogText = e(Dialog.Text, {
				Text = props.body or "Are you sure you want to proceed with this action?",
			}),
		}),
		DialogActions = e(Dialog.Actions, {
			actions = {
				{
					text = "Cancel",
					variant = ButtonVariant.Standard,
					onActivated = function()
						props.onClose(false)
					end,
				} :: any,
				{
					text = "Confirm",
					variant = ButtonVariant.Emphasis,
					onActivated = function()
						props.onClose(true)
					end,
				},
			},
		}),
	})
end

return ConfirmationDialog
