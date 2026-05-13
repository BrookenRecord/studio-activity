local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ActivityPreview = require(Plugin.Source.ActivityPreview)
local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local ProfileContext = require(script.Parent.ProfileContext)
local buildCustomActivity = require(Plugin.Source.PresenceManager.ProfileStore.buildCustomActivity)

type ActivityConfig = buildCustomActivity.ActivityConfig

local View = Foundation.View

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState
local useMemo = React.useMemo

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function PreviewBlock(props: Props)
	local nextOrder = createNextOrder()
	local profile = ProfileContext.useProfile()
	local placeDetailsStore = PlaceDetailsStore.get()

	local currentActivityComputed = useMemo(function()
		return Charm.computed(function(): ActivityConfig?
			local customProfile = profile.profileStore.getProfile()
			local overridePlaceId = customProfile.activity.overridePlaceId
			local placeContext = if overridePlaceId and overridePlaceId > 0
				then placeDetailsStore.getContextByPlaceId(overridePlaceId)
				else placeDetailsStore.getCurrentContext()

			if placeContext == nil then
				return nil
			end

			return buildCustomActivity(placeContext, customProfile)
		end)
	end, { profile.profileStore :: any, placeDetailsStore })

	local currentActivity = useSignalState(currentActivityComputed)

	return e(View, {
		tag = "size-full-0 auto-y col align-x-center padding-bottom-small",
		LayoutOrder = props.LayoutOrder,
	}, {
		PreviewContainer = currentActivity and e(View, {
			tag = "auto-y",
			Size = UDim2.fromScale(0.8, 0),
			sizeConstraint = {
				MaxSize = Vector2.new(300, math.huge),
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
