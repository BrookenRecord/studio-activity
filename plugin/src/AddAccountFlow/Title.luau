local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local View = Foundation.View
local Text = Foundation.Text
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconSize = Foundation.Enums.IconSize
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function Title(props: Props)
	local tokens = useTokens()
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y row gap-medium padding-top-small align-y-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		Discord = e(Icon, {
			name = IconName.Discord,
			size = IconSize.Large,
			style = tokens.Color.Content.Emphasis,
			LayoutOrder = nextOrder(),
		}),

		TextBlock = e(View, {
			tag = "size-full-0 auto-y col",
			LayoutOrder = nextOrder(),
		}, {
			Title = e(Text, {
				tag = "size-full-0 auto-y text-title-medium content-emphasis text-wrap text-align-x-left",
				Text = "Link Discord",
				LayoutOrder = nextOrder(),
			}),

			Subtitle = e(Text, {
				tag = "size-full-0 auto-y text-caption-medium content-default text-wrap text-align-x-left",
				Text = "Show Studio activity on your profile",
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return Title
