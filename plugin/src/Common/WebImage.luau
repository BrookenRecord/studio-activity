local AssetService = game:GetService("AssetService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local png = require(Packages.png)

local Flags = require(Plugin.Source.Flags)
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
	local imageState = useWebImage(props.url)

	local isBig = props.size == "big"

	useEffect(function()
		if imageState.status == "loading" then
			setImageContent(nil)
			setHasError(false)
			return function() end
		end

		if imageState.status == "error" then
			setImageContent(nil)
			setHasError(true)
			return function() end
		end

		local imageData = imageState.data
		local editableImage
		local thread = task.spawn(function()
			local success, err = pcall(function()
				local decoded = png.decode(imageData)

				local size = Vector2.new(decoded.width, decoded.height)
				editableImage = AssetService:CreateEditableImage({
					Size = size,
				})

				editableImage:WritePixelsBuffer(Vector2.zero, size, decoded.pixels)

				local editableImageContent = Content.fromObject(editableImage)
				if Flags.isDataModelContentApiAvailable then
					-- TODO: Remove the type cast when this API has proper types
					local result, content = (AssetService :: any):CreateDataModelContentAsync(editableImageContent)
					-- TODO Luau: This enum is too new for the LSP to type check
					if result == (Enum :: any).CreateContentResult.Success then
						setImageContent(content)
						editableImage:Destroy()
						editableImage = nil :: any
					else
						setImageContent(editableImageContent)
					end
				else
					setImageContent(editableImageContent)
				end

				-- TODO: Migrate to the static content API once available. Should save
				-- a bit of memory.
			end)

			if not success then
				setHasError(true)
				Logger:Warn("Error while rendering web image", {
					error = err,
				})
			else
				setHasError(false)
			end
		end)

		return function()
			task.cancel(thread)
			if editableImage then
				editableImage:Destroy()
			end
			setImageContent(nil)
		end
	end, { imageState :: any })

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
