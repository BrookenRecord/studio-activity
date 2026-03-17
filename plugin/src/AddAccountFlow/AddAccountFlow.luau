local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local Dialog = Foundation.Dialog
local DialogSize = Foundation.Enums.DialogSize

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function AddAccountFlow(props: Props)
	local nextOrder = createNextOrder()

	return e(Dialog.Root, {
		size = DialogSize.Medium,
		disablePortal = false,
		hasBackdrop = true,
		onClose = function() end,
	}, {
		Title = e(Dialog.Title, {
			text = "Link Discord Account",
		}),

		Content = e(Dialog.Content, nil, {
			Message = React.createElement(Foundation.Text, {
				tag = "auto-xy padding-top-medium",
				Text = "Are you sure you want to discard your changes?",
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return AddAccountFlow
