local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ActivityDetails = require(script.Parent.ActivityDetails)
local ActivityImage = require(script.Parent.ActivityImage)
local ActivityTimer = require(script.Parent.ActivityTimer)
local Types = require(script.Parent.Types)

local View = Foundation.View
local Text = Foundation.Text

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	activity: Types.Activity,
	LayoutOrder: number?,
}

local function ActivityPreview(props: Props)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y bg-surface-300 col padding-small gap-medium radius-small stroke-emphasis stroke-thick",
		LayoutOrder = props.LayoutOrder,
	}, {
		Title = e(Text, {
			tag = "auto-xy text-caption-small content-default",
			Text = "Playing",
			LayoutOrder = nextOrder(),
		}),

		Activity = e(View, {
			tag = "auto-xy row gap-large padding-x-xsmall",
			LayoutOrder = nextOrder(),
		}, {
			ActivityImage = e(ActivityImage, {
				assets = props.activity.assets,
				LayoutOrder = nextOrder(),
			}),

			DetailsBlock = e(View, {
				tag = "auto-xy col gap-small",
				LayoutOrder = nextOrder(),
			}, {
				ActivityDetails = e(ActivityDetails, {
					activity = props.activity,
					LayoutOrder = nextOrder(),
				}),

				ActivityTimer = e(ActivityTimer, {
					LayoutOrder = nextOrder(),
				}),
			}),
		}),
	})
end

return ActivityPreview
