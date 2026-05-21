local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local Types = require(script.Parent.Types)

local View = Foundation.View
local Text = Foundation.Text
local Skeleton = Foundation.Skeleton
local Radius = Foundation.Enums.Radius

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	activity: Types.Activity?,
	LayoutOrder: number?,
}

local function ActivityDetails(props: Props)
	local nextOrder = createNextOrder()
	local activity = props.activity

	return e(View, {
		tag = {
			["size-full-0 auto-y col"] = true,
			["gap-xxsmall"] = props.activity ~= nil,
			["gap-xsmall"] = props.activity == nil,
		},
		LayoutOrder = props.LayoutOrder,
	}, {
		Name = if activity
			then e(Text, {
				tag = "size-full-0 auto-y text-align-x-left text-wrap text-title-medium content-emphasis",
				Text = activity.name,
				LayoutOrder = nextOrder(),
			})
			else e(Skeleton, {
				radius = Radius.XSmall,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = nextOrder(),
			}),

		Details = if activity
			then activity.details and e(Text, {
				tag = "size-full-0 auto-y text-align-x-left text-wrap text-body-small content-default",
				Text = activity.details,
				LayoutOrder = nextOrder(),
			})
			else e(Skeleton, {
				radius = Radius.XSmall,
				Size = UDim2.new(0.45, 0, 0, 12),
				LayoutOrder = nextOrder(),
			}),

		State = if activity
			then activity.state and e(Text, {
				tag = "size-full-0 auto-y text-align-x-left text-wrap text-body-small content-default",
				Text = activity.state,
				LayoutOrder = nextOrder(),
			})
			else e(Skeleton, {
				radius = Radius.XSmall,
				Size = UDim2.new(0.6, 0, 0, 12),
				LayoutOrder = nextOrder(),
			}),
	})
end

return ActivityDetails
