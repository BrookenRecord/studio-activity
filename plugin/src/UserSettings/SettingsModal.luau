local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local SettingsView = require(script.Parent.SettingsView)

local Text = Foundation.Text
local Sheet = Foundation.Sheet
local DialogSize = Foundation.Enums.DialogSize

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	isOpen: boolean,
	onClose: (result: any?) -> (),
}

local function SettingsModal(props: Props)
	local nextOrder = createNextOrder()

	return e(Sheet.Root, {
		isOpen = props.isOpen,
		preferCenterSheet = true,
		size = DialogSize.Medium,
		onClose = props.onClose,
	}, {
		Header = e(Sheet.Header, {
			hasCloseAffordance = true,
		}, {
			Title = e(Text, {
				tag = "size-full-0 auto-y text-heading-small content-emphasis text-wrap text-align-x-left",
				Text = "Settings",
				LayoutOrder = nextOrder(),
			}),
		}),

		Content = props.isOpen and e(Sheet.Content, nil, {
			SettingsView = e(SettingsView),
		}),
	})
end

return SettingsModal
