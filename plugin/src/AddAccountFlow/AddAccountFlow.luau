local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local AuthContext = require(script.Parent.AuthContext)
local Content = require(script.Parent.Content)
local Title = require(script.Parent.Title)

local Sheet = Foundation.Sheet
local DialogSize = Foundation.Enums.DialogSize

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	isOpen: boolean,
	onClose: (result: any?) -> (),
}

local function AddAccountFlow(props: Props)
	local nextOrder = createNextOrder()

	return e(Sheet.Root, {
		isOpen = props.isOpen,
		preferCenterSheet = true,
		size = DialogSize.Large,
		disablePortal = false,
		hasBackdrop = true,
		onClose = props.onClose,
	}, {
		Header = e(Sheet.Header, {
			hasCloseAffordance = true,
		}, {
			Title = e(Title, {
				LayoutOrder = nextOrder(),
			}),
		}),

		Content = props.isOpen and e(Sheet.Content, nil, {
			Context = e(ReactUtils.ContextStack, {
				providers = {
					e(AuthContext.Provider, {}),
				},
			}, {
				InnerContent = e(Content),
			}),
		}),
	})
end

return AddAccountFlow
