local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local BrowserFlow = require(script.Parent.BrowserFlow)
local QRCodeFlow = require(script.Parent.QRCodeFlow)

local View = Foundation.View
local Tabs = Foundation.Tabs
local InputSize = Foundation.Enums.InputSize
local FillBehavior = Foundation.Enums.FillBehavior

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function StartPage(props: Props)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y col gap-small",
		sizeConstraint = {
			MinSize = Vector2.new(0, 180),
		},
		LayoutOrder = props.LayoutOrder,
	}, {
		TabSelector = e(Tabs, {
			defaultActiveTabId = "browser",
			onActivated = function() end,
			size = InputSize.Small,
			fillBehavior = FillBehavior.Fill,
			LayoutOrder = nextOrder(),
			tabs = {
				{
					id = "browser",
					text = "Desktop",
					content = e(BrowserFlow) :: any,
				},
				{
					id = "qr-code",
					text = "Mobile",
					content = e(QRCodeFlow) :: any,
				},
			},
		}),
	})
end

return StartPage
