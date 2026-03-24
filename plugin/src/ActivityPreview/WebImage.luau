local AssetService = game:GetService("AssetService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local png = require(Packages.png)

local Logger = require(Plugin.Source.Logger)
local useWebImage = require(script.Parent.useWebImage)

local View = Foundation.View
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconSize = Foundation.Enums.IconSize
local useTokens = Foundation.Hooks.useTokens

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect

type Props = {
	url: string,
	size: "big" | "small",
	LayoutOrder: number?,
}

local function WebImage(props: Props)
	local tokens = useTokens()

	local imageContent, setImageContent = useState<<Content?>>(nil)
	local hasError, setHasError = useState(false)
	local imageData = useWebImage(props.url)

	local isBig = props.size == "big"

	useEffect(function()
		if imageData == nil then
			setHasError(true)
			return
		end

		local editableImage
		local success, err = pcall(function()
			local decoded = png.decode(imageData)

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
			Logger:Warn("Error while rendering web image", {
				error = err,
			})
		end

		setHasError(false)

		return function()
			if editableImage then
				editableImage:Destroy()
			end
			setImageContent(nil)
		end
	end, { imageData })

	return e(View, {
		tag = {
			["size-full bg-shift-100 row align-y-center align-x-center"] = true,
			["radius-small"] = isBig,
			["radius-circle"] = not isBig,
		},
		LayoutOrder = props.LayoutOrder,
	}, {
		ErrorIcon = hasError and e(Icon, {
			name = IconName.SquareFaceEmoji,
			size = if isBig then IconSize.Medium else IconSize.XSmall,
		}),

		Image = (not hasError) and e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageContent = imageContent,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = if isBig then UDim.new(0, tokens.Radius.Small) else UDim.new(1, 0),
			}),
		}),
	})
end

return WebImage
