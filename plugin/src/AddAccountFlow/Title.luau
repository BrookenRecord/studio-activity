local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local PluginWordmark = require(Plugin.Source.Common.PluginWordmark)

local View = Foundation.View
local Text = Foundation.Text
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
		tag = "size-full-0 auto-y row gap-small padding-y-small align-y-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		LogoBlock = e(PluginWordmark, {
			size = "small",
			LayoutOrder = nextOrder(),
		}),

		Divider = e(View, {
			Size = UDim2.fromOffset(1, tokens.Size.Size_800),
			backgroundStyle = tokens.Color.Stroke.Default,
			LayoutOrder = nextOrder(),
		}),

		TextBlock = e(View, {
			tag = "size-full-0 auto-y col gap-xsmall",
			LayoutOrder = nextOrder(),
		}, {
			Title = e(Text, {
				tag = "size-full-0 auto-y text-title-medium content-emphasis text-wrap text-align-x-left",
				Text = "Link Discord Account",
				LayoutOrder = nextOrder(),
			}),

			Subtitle = e(Text, {
				tag = "size-full-0 auto-y text-caption-medium content-default text-wrap text-align-x-left",
				Text = "Show your Studio activity on your Discord profile.",
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return Title
