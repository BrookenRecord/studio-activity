local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local Types = require(script.Parent.Types)
local useRefProperty = require(Plugin.Source.Common.useRefProperty)

local View = Foundation.View
local Image = Foundation.Image
local Skeleton = Foundation.Skeleton
local Tooltip = Foundation.Tooltip
local Radius = Foundation.Enums.Radius
local PopoverSide = Foundation.Enums.PopoverSide
local PopoverAlign = Foundation.Enums.PopoverAlign

local e = React.createElement
local useRef = React.useRef

type Props = {
	assets: Types.ActivityAssets?,
	LayoutOrder: number?,
}

local function ActivityImage(props: Props)
	local largeImage = props.assets and props.assets.largeImage
	local largeText = props.assets and props.assets.largeText
	local smallImage = props.assets and props.assets.smallImage
	local smallText = props.assets and props.assets.smallText

	local imageRef = useRef(nil)
	local isLoaded = useRefProperty(imageRef, "IsLoaded", false)

	local largeBlock = e(View, {
		tag = "size-full",
	}, {
		Image = e(Image, {
			tag = "size-full radius-small",
			Image = largeImage,
		}),

		LoadingSkeleton = (not isLoaded) and e(Skeleton, {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			radius = Radius.Small,
		}),
	})

	local smallImageBlock = e(View, {
		tag = "size-800-800 bg-surface-300 radius-circle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 1, -4),
		ZIndex = 2,
	})

	return e(View, {
		tag = "size-1600-1600",
		LayoutOrder = props.LayoutOrder,
	}, {
		LargeImageBlock = if largeText
			then e(Tooltip, {
				title = largeText,
				align = PopoverAlign.Center,
				side = PopoverSide.Top,
			}, largeBlock)
			else largeBlock,

		SmallImageBlock = smallImage and if smallText
			then e(Tooltip, {
				title = smallText,
				align = PopoverAlign.Center,
				side = PopoverSide.Top,
			}, smallImageBlock)
			else smallImageBlock,
	})
end

return React.memo(ActivityImage)
