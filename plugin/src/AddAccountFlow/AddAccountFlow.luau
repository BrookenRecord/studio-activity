local Plugin = script:FindFirstAncestor("StudioRichPresence")

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
	LayoutOrder: number?,
}

local function AddAccountFlow(_props: Props)
	local nextOrder = createNextOrder()

	return e(ReactUtils.ContextStack, {
		providers = {
			e(AuthContext.Provider, {}),
		},
	}, {
		Sheet = e(Sheet.Root, {
			isOpen = true,
			preferCenterSheet = true,
			size = DialogSize.Large,
			disablePortal = false,
			hasBackdrop = true,
			onClose = function() end,
		}, {
			Header = e(Sheet.Header, {
				hasCloseAffordance = true,
			}, {
				Title = e(Title, {
					LayoutOrder = nextOrder(),
				}),
			}),

			Content = e(Sheet.Content, nil, {
				StartPage = e(StartPage, {
					LayoutOrder = nextOrder(),
				}),
			}),
		}),
	})
end

return AddAccountFlow
