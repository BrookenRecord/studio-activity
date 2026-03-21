local AssetService = game:GetService("AssetService")
local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local png = require(Packages.png)

local DiscordApi = require(Plugin.Source.Api.Discord)
type AvatarImage = DiscordApi.AvatarImage

local View = Foundation.View

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

type Props = {
	avatar: AvatarImage,
	size: number,
	LayoutOrder: number?,
}

local function DiscordAvatar(props: Props)
	local imageContent, setImageContent = useState<<Content?>>(nil)
	local hasError, setHasError = useState(false)

	useEffect(function()
		if props.avatar.contentType ~= "image/png" then
			setHasError(true)
			return
		end

		local pixelBuf = buffer.fromstring(props.avatar.data)
		local decoded = png.decode(pixelBuf)

		local size = Vector2.new(decoded.width, decoded.height)
		local editableImage = AssetService:CreateEditableImage({
			Size = size,
		})

		editableImage:WritePixelsBuffer(Vector2.zero, size, decoded.pixels)

		setImageContent(Content.fromObject(editableImage))

		return function()
			editableImage:Destroy()
			setImageContent(nil)
		end
	end, { props.avatar })

	return e(View, {
		Size = UDim2.fromOffset(props.size, props.size),
		LayoutOrder = props.LayoutOrder,
	}, {
		Image = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageContent = imageContent,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

return React.memo(DiscordAvatar)
