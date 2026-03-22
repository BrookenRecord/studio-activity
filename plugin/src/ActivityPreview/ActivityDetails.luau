local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local Types = require(script.Parent.Types)

local View = Foundation.View
local Text = Foundation.Text

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	activity: Types.Activity,
	LayoutOrder: number?,
}

local function ActivityDetails(props: Props)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "auto-xy col gap-xxsmall",
		LayoutOrder = props.LayoutOrder,
	}, {
		Name = e(Text, {
			tag = "auto-xy text-title-medium content-emphasis",
			Text = props.activity.name,
			LayoutOrder = nextOrder(),
		}),

		Details = e(Text, {
			tag = "auto-xy text-body-small content-default",
			Text = props.activity.details,
			LayoutOrder = nextOrder(),
		}),

		State = e(Text, {
			tag = "auto-xy text-body-small content-default",
			Text = props.activity.state,
			LayoutOrder = nextOrder(),
		}),
	})
end

return ActivityDetails
