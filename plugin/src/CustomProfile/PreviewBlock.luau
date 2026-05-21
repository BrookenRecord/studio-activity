local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ActivityPreview = require(Plugin.Source.ActivityPreview)
local BuildContext = require(Plugin.Source.PresenceManager.ProfileStore.BuildContext)
local PlaceDetailsStore = require(Plugin.Source.PlaceDetailsStore)
local PluginContextStore = require(Plugin.Source.PluginContextStore)
local PresenceManager = require(Plugin.Source.PresenceManager)
local ProfileContext = require(script.Parent.ProfileContext)
local buildCustomActivity = require(Plugin.Source.PresenceManager.ProfileStore.buildCustomActivity)

type ActivityConfig = buildCustomActivity.ActivityConfig
type BuildContext = BuildContext.BuildContext

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
	local pluginContextStore = PluginContextStore.get()
	local presenceManager = PresenceManager.get()

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

			local buildContext: BuildContext = {
				place = placeContext,
				studio = pluginContextStore.getStudioContext(),
			}

			local activity = buildCustomActivity(buildContext, customProfile)
			activity.startedAt = presenceManager.getSessionStartedAt()
			return activity
		end)
	end, { profile.profileStore :: any, placeDetailsStore, pluginContextStore, presenceManager })

	local currentActivity = useSignalState(currentActivityComputed)

	return e(View, {
		tag = "size-full-0 auto-y col align-x-center padding-bottom-small",
		LayoutOrder = props.LayoutOrder,
	}, {
		PreviewContainer = e(View, {
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
