local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local Types = require(script.Parent.Types)

local View = Foundation.View
local Button = Foundation.Button
local Tooltip = Foundation.Tooltip
local InputSize = Foundation.Enums.InputSize
local ButtonVariant = Foundation.Enums.ButtonVariant
local FillBehavior = Foundation.Enums.FillBehavior
local PopoverAlign = Foundation.Enums.PopoverAlign
local PopoverSide = Foundation.Enums.PopoverSide

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

local function NOOP() end

type Props = {
	buttons: { Types.ActivityButton },
	LayoutOrder: number?,
}

local function ActivityButtons(props: Props)
	local nextOrder = createNextOrder()

	local buttonChildren: { React.ReactNode } = {}
	for index, button in props.buttons do
		table.insert(
			buttonChildren,
			e(Button, {
				text = button.label,
				key = tostring(index),
				size = InputSize.Small,
				variant = if index == 1 then ButtonVariant.SoftEmphasis else ButtonVariant.Standard,
				fillBehavior = FillBehavior.Fill,
				width = UDim.new(1, 0),
				LayoutOrder = index,
				onActivated = NOOP,
			})
		)
	end

	return e(Tooltip, {
		title = if #props.buttons == 1
			then "You won't see this button on your own profile"
			else "You won't see these buttons on your own profile",
		align = PopoverAlign.Center,
		side = PopoverSide.Top,
		LayoutOrder = props.LayoutOrder,
	}, {
		ButtonsContainer = e(View, {
			tag = "size-full-0 auto-y col gap-small",
			LayoutOrder = nextOrder(),
		}, buttonChildren),
	})
end

return ActivityButtons
