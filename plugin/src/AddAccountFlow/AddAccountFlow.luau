local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local AuthContext = require(script.Parent.AuthContext)
local StartPage = require(script.Parent.StartPage.StartPage)
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
		size = DialogSize.Medium,
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
					e(AuthContext.Provider, {
						onClose = props.onClose,
					}),
				},
			}, {
				-- This was setup to have multiple pages, but not sure if it
				-- will anymore.
				StartPage = e(StartPage, {
					LayoutOrder = nextOrder(),
				}),
			}),
		}),
	})
end

return AddAccountFlow
