local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local useTimerText = require(script.Parent.useTimerText)

local View = Foundation.View
local Text = Foundation.Text
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconVariant = Foundation.Enums.IconVariant
local IconSize = Foundation.Enums.IconSize
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement
local useMemo = React.useMemo

type Props = {
	LayoutOrder: number?,
}

local function ActivityTimer(props: Props)
	local nextOrder = createNextOrder()

	local tokens = useTokens()
	local contentColor = tokens.Color.Extended.Green.Green_500

	-- TODO: Grab this from the same time value we're actually using.
	local startTime = useMemo(function()
		return os.time()
	end, {})

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

		TimerText = e(Text, {
			tag = "auto-xy text-body-small",
			textStyle = contentColor,
			Text = timerText,
			LayoutOrder = nextOrder(),
		}),
	})
end

return ActivityTimer
