local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AppAssetsStore = require(Plugin.Source.Api.AppAssetsStore)
local Types = require(script.Parent.Types)
local WebImage = require(Plugin.Source.Common.WebImage)

local View = Foundation.View
local Tooltip = Foundation.Tooltip
local Skeleton = Foundation.Skeleton
local PopoverSide = Foundation.Enums.PopoverSide
local PopoverAlign = Foundation.Enums.PopoverAlign
local Radius = Foundation.Enums.Radius
local useTokens = Foundation.Hooks.useTokens

local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	assets: Types.ActivityAssets?,
	LayoutOrder: number?,
}

local function ActivityImage(props: Props)
	local tokens = useTokens()
	local appAssets = AppAssetsStore.get()

	-- Subscribe to the assets signal so the component re-renders when
	-- the async fetch completes and the name->id map becomes available.
	useSignalState(appAssets.getAssetsByName)

	local rawLargeImage = props.assets and props.assets.largeImage
	local largeText = props.assets and props.assets.largeText
	local rawSmallImage = props.assets and props.assets.smallImage
	local smallText = props.assets and props.assets.smallText

	local largeImageUrl = if rawLargeImage then appAssets.resolveUrl(rawLargeImage) else nil
	local smallImageUrl = if rawSmallImage then appAssets.resolveUrl(rawSmallImage) else nil

	local largeBlock = if largeImageUrl
		then e(View, {
			tag = "size-full",
		}, {
			Image = e(WebImage, {
				url = largeImageUrl,
				size = "big",
			}),
		})
		else e(Skeleton, {
			radius = Radius.Small,
			Size = UDim2.fromScale(1, 1),
		})

	local smallImageBlock = if smallImageUrl
		then e(WebImage, {
			url = smallImageUrl,
			size = "small",
		})
		elseif rawSmallImage then e(Skeleton, {
			radius = Radius.Circle,
			Size = UDim2.fromScale(1, 1),
		})
		else nil

	return e(View, {
		tag = "size-1600-1600",
		LayoutOrder = props.LayoutOrder,
	}, {
		LargeImageBlock = largeBlock and if largeText
			then e(Tooltip, {
				title = largeText,
				align = PopoverAlign.Center,
				side = PopoverSide.Top,
			}, largeBlock)
			else largeBlock,

		SmallImageBlock = rawSmallImage and e(View, {
			tag = "size-700-700 bg-surface-300 radius-circle",
			stroke = {
				Color = tokens.Color.Surface.Surface_300.Color3,
				Thickness = tokens.Stroke.Thicker,
			},
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -9, 1, -9),
			ZIndex = 2,
		}, {
			Image = if smallText
				then e(Tooltip, {
					title = smallText,
					align = PopoverAlign.Center,
					side = PopoverSide.Top,
					ZIndex = 2,
				}, smallImageBlock)
				else smallImageBlock,
		}),
	})
end

return React.memo(ActivityImage)
