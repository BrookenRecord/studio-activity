local AssetService = game:GetService("AssetService")

local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local ErrorCorrection = require(script.Parent.ErrorCorrection)
local renderMatrixToImage = require(script.Parent.renderMatrixToImage)
local useQRCodeMatrix = require(script.Parent.useQRCodeMatrix)

local View = Foundation.View

local e = React.createElement

export type Props = {
	text: string,
	errorCorrection: ErrorCorrection.Level,
	size: number,
	color: Color3?,
	transparency: number?,
	rotation: number?,
	LayoutOrder: number?,
}

local DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)

--[[
	When the QR code is rotated inside its bounding box, it needs to shrink
	so the corners don't clip. A rotated square of side `s` has a bounding
	box of `s * (sinθ + cosθ)`, so:  s = boundingBox / (sinθ + cosθ).
]]
local function computeRotatedSize(boundingBox: number, rotation: number?): number
	if not rotation or rotation % 90 == 0 then
		return boundingBox
	end
	local radians = math.rad(rotation)
	return math.round(boundingBox / (math.sin(radians) + math.cos(radians)))
end

local function QRCodeDisplay(props: Props)
	local color = props.color or DEFAULT_COLOR
	local transparency = props.transparency or 0
	local imageSize = computeRotatedSize(props.size, props.rotation)

	local matrix = useQRCodeMatrix(props.text, props.errorCorrection)
	local imageRef = React.useRef(nil :: EditableImage?)
	local content, setContent = React.useState(nil :: Content?)
	local renderSize = imageSize * 2

	React.useEffect(function()
		local image = imageRef.current
		if not image or image.Size.X ~= renderSize then
			if image then
				image:Destroy()
			end
			image = AssetService:CreateEditableImage({
				Size = Vector2.new(renderSize, renderSize),
			})

			assert(image, "luau")
			imageRef.current = image
			setContent(Content.fromObject(image))
		end

		assert(image, "luau")
		renderMatrixToImage(image, renderSize, matrix, color, 1 - transparency)
	end, { renderSize :: any, matrix, color, transparency })

	-- Destroy the EditableImage on unmount
	React.useEffect(function()
		return function()
			if imageRef.current then
				imageRef.current:Destroy()
			end
		end
	end, {})

	return e(View, {
		Size = UDim2.fromOffset(props.size, props.size),
		LayoutOrder = props.LayoutOrder,
	}, {
		QRImage = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ImageContent = content,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = props.rotation,
			Size = UDim2.fromOffset(imageSize, imageSize),
		}),
	})
end

return QRCodeDisplay
