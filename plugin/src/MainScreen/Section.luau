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
local useState = React.useState

type Props = {
	title: string,
	hasDivider: boolean,
	LayoutOrder: number?,
	children: React.ReactNode,
}

local function Section(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	local isExpanded, setExpanded = useState(true)

	return e(View, {
		tag = "size-full-0 auto-y col",
		LayoutOrder = props.LayoutOrder,
	}, {
		LayoutContainer = e(View, {
			tag = "size-full-0 auto-y col gap-small padding-x-small padding-y-medium",
			LayoutOrder = nextOrder(),
		}, {
			HeaderBlock = e(View, {
				tag = "size-full-0 auto-y row radius-small align-y-center padding-x-small padding-y-xsmall",
				LayoutOrder = nextOrder(),
				onActivated = function()
					setExpanded(function(prev)
						return not prev
					end)
				end,
			}, {
				Title = e(Text, {
					tag = "auto-y grow text-align-x-left text-title-small content-muted",
					Text = props.title,
					LayoutOrder = nextOrder(),
				}),

				ExpandedIcon = e(Icon, {
					name = if isExpanded then IconName.ChevronLargeDown else IconName.ChevronLargeUp,
					size = IconSize.XSmall,
					LayoutOrder = nextOrder(),
				}),
			}),

			Container = e(View, {
				tag = "size-full-0 auto-y col gap-xsmall padding-x-small",
				LayoutOrder = nextOrder(),
				-- Some of the contents are heavy to re-render, so just make the
				-- container invisible instead of unmounting.
				Visible = isExpanded,
			}, props.children),
		}),

		Divider = props.hasDivider and e(View, {
			backgroundStyle = tokens.Color.Stroke.Muted,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = nextOrder(),
		}),
	})
end

return Section
