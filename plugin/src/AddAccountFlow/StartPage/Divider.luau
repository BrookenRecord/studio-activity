local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local View = Foundation.View
local Text = Foundation.Text
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	label: string?,
	LayoutOrder: number?,
}

local function Divider(props: Props)
	local tokens = useTokens()
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-300 row gap-medium align-y-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		LeftDivider = e(View, {
			tag = "grow",
			Size = UDim2.fromOffset(0, 1),
			backgroundStyle = tokens.Color.Shift.Shift_200,
			LayoutOrder = nextOrder(),
		}),

		Label = props.label and e(Text, {
			tag = "auto-xy text-label-small content-muted",
			Text = props.label,
			LayoutOrder = nextOrder(),
		}),

		RightDivider = props.label and e(View, {
			tag = "grow",
			Size = UDim2.fromOffset(0, 1),
			backgroundStyle = tokens.Color.Shift.Shift_200,
			LayoutOrder = nextOrder(),
		}),
	})
end

return Divider
