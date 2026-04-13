local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ActivityPreview = require(Plugin.Source.ActivityPreview)
local PlaceContextStore = require(Plugin.Source.PlaceContextStore)
local ProfileContext = require(script.Parent.ProfileContext)
local buildCustomActivity = require(Plugin.Source.PresenceManager.ProfileStore.buildCustomActivity)

local View = Foundation.View

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function PreviewBlock(props: Props)
	local nextOrder = createNextOrder()
	local profile = ProfileContext.useProfile()

	local currentActivity = useSignalState(Charm.computed(function()
		local placeContext = PlaceContextStore.get().getContext()
		if placeContext == nil then
			error("Expected place context")
		end

		local customProfile = profile.profileStore.getProfile()
		return buildCustomActivity(placeContext, customProfile)
	end))

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
