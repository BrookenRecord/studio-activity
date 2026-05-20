local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local useTimerText = require(script.Parent.useTimerText)

local View = Foundation.View
local Text = Foundation.Text
local Icon = Foundation.Icon
local Skeleton = Foundation.Skeleton
local IconName = Foundation.Enums.IconName
local IconVariant = Foundation.Enums.IconVariant
local IconSize = Foundation.Enums.IconSize
local Radius = Foundation.Enums.Radius
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement
local useMemo = React.useMemo

type Props = {
	startedAt: number?,
	LayoutOrder: number?,
}

local function ActivityTimer(props: Props)
	local nextOrder = createNextOrder()

	local tokens = useTokens()
	local contentColor = if props.startedAt then tokens.Color.Extended.Green.Green_500 else tokens.Color.System.Neutral

	local startTime = useMemo(function()
		return props.startedAt or os.time()
	end, { props.startedAt })

	local timerText = useTimerText(startTime)

	return e(View, {
		tag = "auto-xy row align-y-center gap-xsmall",
		LayoutOrder = props.LayoutOrder,
	}, {
		Icon = e(Icon, {
			name = IconName.PersonPlayClock,
			variant = IconVariant.Filled,
			size = IconSize.XSmall,
			style = contentColor,
			LayoutOrder = nextOrder(),
		}),

		TimerText = if props.startedAt
			then e(Text, {
				tag = "auto-xy text-body-small",
				textStyle = contentColor,
				Text = timerText,
				LayoutOrder = nextOrder(),
			})
			else e(Skeleton, {
				radius = Radius.XSmall,
				Size = UDim2.fromOffset(42, 12),
				LayoutOrder = nextOrder(),
			}),
	})
end

return ActivityTimer
