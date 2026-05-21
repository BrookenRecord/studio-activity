local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ModalStore = require(Plugin.Source.Modal.ModalStore)
local ProfileContext = require(script.Parent.ProfileContext)

local Sheet = Foundation.Sheet
local Button = Foundation.Button
local IconButton = Foundation.IconButton
local ButtonVariant = Foundation.Enums.ButtonVariant
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName
local FillBehavior = Foundation.Enums.FillBehavior

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	isNewProfile: boolean,
	onClose: (result: any?) -> (),
}

local function ProfileActions(props: Props)
	local nextOrder = createNextOrder()
	local profile = ProfileContext.useProfile()

	return e(Sheet.Actions, nil, {
		Save = e(Button, {
			text = if props.isNewProfile then "Create Profile" else "Save Profile",
			size = InputSize.Small,
			variant = ButtonVariant.Emphasis,
			fillBehavior = FillBehavior.Fill,
			LayoutOrder = nextOrder(),
			onActivated = function()
				profile.profileStore.save({ activate = props.isNewProfile })
				props.onClose(true)
			end,
		}),

		Delete = (not props.isNewProfile) and e(IconButton, {
			icon = IconName.TrashCan,
			size = InputSize.Small,
			LayoutOrder = nextOrder(),
			onActivated = function()
				local accepted = ModalStore.get().openAsync("confirmation", {
					priority = 2,
					props = {
						title = "Delete this profile?",
						body = "This action cannot be undone.",
					},
				})

				if accepted then
					profile.profileStore.delete()
					props.onClose(false)
				end
			end,
		}),
	})
end

return ProfileActions
