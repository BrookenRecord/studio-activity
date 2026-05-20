local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ActivityButtons = require(script.Parent.ActivityButtons)
local ActivityDetails = require(script.Parent.ActivityDetails)
local ActivityImage = require(script.Parent.ActivityImage)
local ActivityTimer = require(script.Parent.ActivityTimer)
local Flags = require(Plugin.Source.Flags)
local Types = require(script.Parent.Types)

local View = Foundation.View
local Text = Foundation.Text

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	activity: Types.Activity?,
	LayoutOrder: number?,
}

local function ActivityPreview(props: Props)
	local nextOrder = createNextOrder()
	local activity = props.activity

	return e(View, {
		tag = "size-full-0 auto-y bg-surface-300 clip col padding-small gap-medium radius-small stroke-emphasis stroke-thick",
		LayoutOrder = props.LayoutOrder,
	}, {
		Shadow = Flags.isShadowAvailable and e("UIShadow", {
			Transparency = 0.85,
			BlurRadius = UDim.new(0, 12),
		}),

		Title = e(Text, {
			tag = "auto-xy text-caption-small content-default",
			Text = "Live Preview",
			LayoutOrder = nextOrder(),
		}),

		Activity = e(View, {
			tag = "size-full-0 auto-y row gap-large padding-x-xsmall align-y-top",
			sizeConstraint = {
				MaxSize = Vector2.new(math.huge, 300),
			},
			LayoutOrder = nextOrder(),
		}, {
			ActivityImage = e(ActivityImage, {
				assets = if activity then activity.assets else nil,
				LayoutOrder = nextOrder(),
			}),

			DetailsBlock = e(View, {
				tag = "grow auto-y col gap-xsmall",
				LayoutOrder = nextOrder(),
			}, {
				ActivityDetails = e(ActivityDetails, {
					activity = activity,
					LayoutOrder = nextOrder(),
				}),

				ActivityTimer = e(ActivityTimer, {
					startedAt = if activity then activity.startedAt else nil,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),

		ActivityButtons = (activity and activity.buttons and #activity.buttons > 0) and e(ActivityButtons, {
			buttons = activity.buttons,
			LayoutOrder = nextOrder(),
		}),
	})
end

return ActivityPreview
