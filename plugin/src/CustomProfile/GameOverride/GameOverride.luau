local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local OverridePreview = require(script.Parent.OverridePreview)
local ProfileContext = require(script.Parent.Parent.ProfileContext)
local Section = require(Plugin.Source.Common.Section)

local View = Foundation.View
local NumberInput = Foundation.NumberInput
local InputSize = Foundation.Enums.InputSize
local NumberInputControlsVariant = Foundation.Enums.NumberInputControlsVariant

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function GameOverride(props: Props)
	local nextOrder = createNextOrder()
	local profile = ProfileContext.useProfile()

	local override = useSignalState(profile.profileStore.getOverrideLookupState)

	return e(Section, {
		title = "Game Override",
		canToggleExpand = true,
		hasDivider = false,
		LayoutOrder = props.LayoutOrder,
	}, {
		LayoutBlock = e(View, {
			tag = "size-full-0 auto-y col gap-medium",
			LayoutOrder = nextOrder(),
		}, {
			PlaceIdInput = e(NumberInput, {
				label = "Place ID",
				hint = "Optionally override the game displayed on your activity. If unset, the place you're currently editing will be used instead.",
				value = override.placeId or 0,
				onChanged = function(placeId: number)
					profile.profileStore.setOverrideLookupInput(if placeId == 0 then "" else tostring(placeId))
				end,
				formatAsString = function(placeId: number)
					return if override.status == "loading"
						then "Loading..."
						elseif placeId == 0 then "None"
						else tostring(placeId)
				end,
				controlsVariant = NumberInputControlsVariant.None,
				size = InputSize.Small,
				width = UDim.new(1, 0),
				LayoutOrder = nextOrder(),
			}),

			OverridePreview = e(OverridePreview, {
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return React.memo(GameOverride)
