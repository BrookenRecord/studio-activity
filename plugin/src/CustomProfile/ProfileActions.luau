local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ProfileContext = require(script.Parent.ProfileContext)

local Sheet = Foundation.Sheet
local Button = Foundation.Button
local ButtonVariant = Foundation.Enums.ButtonVariant
local InputSize = Foundation.Enums.InputSize
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
			LayoutOrder = nextOrder(),
			text = if props.isNewProfile then "Create Profile" else "Save Profile",
			size = InputSize.Small,
			variant = ButtonVariant.Emphasis,
			fillBehavior = FillBehavior.Fill,
			onActivated = function()
				profile.profileStore.save()
				props.onClose(true)
			end,
		}),
	})
end

return ProfileActions
