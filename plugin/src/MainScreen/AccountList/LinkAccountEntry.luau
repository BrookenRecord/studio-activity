local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local View = Foundation.View
local Text = Foundation.Text
local Icon = Foundation.Icon
local IconSize = Foundation.Enums.IconSize
local IconName = Foundation.Enums.IconName
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function LinkAccountEntry(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	return e(View, {
		tag = "size-full-1400 row gap-medium padding-x-medium align-y-center radius-small",
		onActivated = function() end,
		LayoutOrder = props.LayoutOrder,
	}, {
		IconBlock = e(View, {
			tag = "radius-circle row align-x-center align-y-center stroke-muted stroke-thin",
			Size = UDim2.fromOffset(tokens.Size.Size_1000, tokens.Size.Size_1000),
		}, {
			Icon = e(Icon, {
				name = IconName.PlusSmall,
				size = IconSize.Medium,
			}),
		}),

		Label = e(Text, {
			tag = "auto-xy text-label-medium content-muted",
			Text = "Link another account",
			LayoutOrder = nextOrder(),
		}),
	})
end

return LinkAccountEntry
