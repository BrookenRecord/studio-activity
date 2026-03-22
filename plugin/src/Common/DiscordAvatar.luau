local AssetService = game:GetService("AssetService")
local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local png = require(Packages.png)

local Logger = require(Plugin.Source.Logger)

local DiscordApi = require(Plugin.Source.Api.Discord)
type AvatarImage = DiscordApi.AvatarImage

local View = Foundation.View
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconSize = Foundation.Enums.IconSize

local e = React.createElement
local useEffect = React.useEffect
local useState = React.useState

type Props = {
	avatar: AvatarImage,
	size: number,
	isDimmed: boolean,
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

		local editableImage
		local success, err = pcall(function()
			local pixelBuf = buffer.fromstring(props.avatar.data)
			local decoded = png.decode(pixelBuf)

			local size = Vector2.new(decoded.width, decoded.height)
			editableImage = AssetService:CreateEditableImage({
				Size = size,
			})

			editableImage:WritePixelsBuffer(Vector2.zero, size, decoded.pixels)

			-- TODO: Migrate to the static content API once available. Should save
			-- a bit of memory.
			setImageContent(Content.fromObject(editableImage))
		end)

		if not success then
			setHasError(true)
			Logger:Warn("Error while rendering Discord avatar", {
				error = err,
			})
		end

		return function()
			if editableImage then
				editableImage:Destroy()
			end
			setImageContent(nil)
		end
	end, { props.avatar })

	return e(View, {
		tag = "bg-surface-100 radius-circle row align-y-center align-x-center",
		Size = UDim2.fromOffset(props.size, props.size),
		LayoutOrder = props.LayoutOrder,
	}, {
		ErrorIcon = hasError and e(Icon, {
			name = IconName.SquareFaceEmoji,
			size = IconSize.Medium,
		}),

		Image = (not hasError) and e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageTransparency = if props.isDimmed then 0.6 else 0,
			ImageContent = imageContent,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

return React.memo(DiscordAvatar)
