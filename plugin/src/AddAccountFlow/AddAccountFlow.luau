local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

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

	return e(Sheet.Root, {
		isOpen = true,
		preferCenterSheet = true,
		-- centerSheetHeight = 0.8,
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
	})
end

return AddAccountFlow
