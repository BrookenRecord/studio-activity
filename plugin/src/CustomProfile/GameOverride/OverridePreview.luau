local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ProfileContext = require(script.Parent.Parent.ProfileContext)
local WebImage = require(Plugin.Source.Common.WebImage)

local View = Foundation.View
local Text = Foundation.Text
local Skeleton = Foundation.Skeleton
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconSize = Foundation.Enums.IconSize
local Radius = Foundation.Enums.Radius

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function OverridePreview(props: Props)
	local nextOrder = createNextOrder()
	local profile = ProfileContext.useProfile()

	local override = useSignalState(profile.profileStore.getOverrideLookupState)

	local placeDetails = override.context and override.context.onlinePlaceDetails
	local iconWebUrl = placeDetails and placeDetails.iconWebUrl

	return e(View, {
		tag = "size-full-1200 bg-shift-100 radius-small row gap-medium padding-x-medium align-y-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		IconBlock = e(View, {
			tag = "size-900-900 bg-shift-100 radius-circle row align-x-center align-y-center",
			LayoutOrder = nextOrder(),
		}, {
			LoadingSkeleton = (override.status == "loading") and e(Skeleton, {
				radius = Radius.Circle,
				LayoutOrder = nextOrder(),
			}),

			Icon = (
				override.status == "idle"
				or override.status == "error"
				or (override.status == "ready" and iconWebUrl == nil)
			)
				and e(Icon, {
					name = if override.status == "idle"
						then IconName.EyeSlash
						elseif iconWebUrl == nil then IconName.CameraSlash
						else IconName.TriangleExclamation,
					size = IconSize.Small,
					LayoutOrder = nextOrder(),
				}),

			GameIcon = (override.status == "ready" and iconWebUrl) and e(WebImage, {
				url = iconWebUrl,
				size = "small",
				LayoutOrder = nextOrder(),
			}),
		}),

		TextBlock = e(View, {
			tag = {
				["size-0-full grow col align-y-center"] = true,
				["gap-xsmall"] = override.status == "loading",
			},
			LayoutOrder = nextOrder(),
		}, {
			Title = if override.status == "loading"
				then e(Skeleton, {
					Size = UDim2.new(0.4, 0, 0, 14),
					radius = Radius.Small,
					LayoutOrder = nextOrder(),
				})
				else e(Text, {
					tag = "size-full-0 auto-y text-wrap text-align-x-left text-title-small content-default",
					Text = if override.status == "ready"
						then "Overriding Activity"
						elseif override.status == "idle" then "No override set"
						else "We ran into an issue",
					LayoutOrder = nextOrder(),
				}),

			Subtitle = if override.status == "loading"
				then e(Skeleton, {
					Size = UDim2.new(0.5, 0, 0, 12),
					radius = Radius.Small,
					LayoutOrder = nextOrder(),
				})
				else override.status ~= "idle" and e(Text, {
					tag = "size-full-0 auto-y text-wrap text-align-x-left text-body-small content-muted",
					Text = if placeDetails then placeDetails.placeName else override.error or "Unknown error",
					LayoutOrder = nextOrder(),
				}),
		}),
	})
end

return OverridePreview
