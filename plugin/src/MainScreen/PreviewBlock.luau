local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ActivityPreview = require(Plugin.Source.ActivityPreview)
local ProfileStore = require(Plugin.Source.PresenceManager.ProfileStore)

local View = Foundation.View

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function PreviewBlock(props: Props)
	local nextOrder = createNextOrder()

	local profileStore = ProfileStore.get()
	local currentActivity = useSignalState(profileStore.getResolvedActivity)

	return e(View, {
		tag = "size-full-0 auto-y col align-x-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		PreviewContainer = currentActivity and e(View, {
			tag = "auto-y",
			Size = UDim2.fromScale(0.6, 0),
			sizeConstraint = {
				MaxSize = Vector2.new(280, math.huge),
			},
			LayoutOrder = nextOrder(),
		}, {
			Preview = e(ActivityPreview, {
				activity = currentActivity,
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return React.memo(PreviewBlock)
