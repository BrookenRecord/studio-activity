local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local View = Foundation.View
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconSize = Foundation.Enums.IconSize
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	size: "small" | "big",
	LayoutOrder: number?,
}

local function PluginWordmark(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	local isBig = props.size == "big"
	local logoSize: Foundation.IconSize = if isBig then IconSize.Large else IconSize.Medium
	local dividerSize: Foundation.IconSize = if isBig then IconSize.Medium else IconSize.Small

	return e(View, {
		tag = {
			["auto-xy row align-y-center"] = true,
			["gap-xsmall"] = isBig,
			["gap-xxsmall"] = not isBig,
		},
		LayoutOrder = props.LayoutOrder,
	}, {
		Discord = e(Icon, {
			name = IconName.Discord,
			size = logoSize,
			style = tokens.Color.Content.Emphasis,
			LayoutOrder = nextOrder(),
		}),

		ArrowIcon = e(Icon, {
			name = IconName.DualArrowsHorizontal,
			size = dividerSize,
			LayoutOrder = nextOrder(),
		}),

		Studio = e(Icon, {
			name = IconName.Studio,
			size = logoSize,
			style = tokens.Color.Content.Emphasis,
			LayoutOrder = nextOrder(),
		}),
	})
end

return React.memo(PluginWordmark)
