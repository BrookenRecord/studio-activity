local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local Logger = require(Plugin.Source.Logger)

local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local function useWebImage(url: string): buffer?
	local imageData, setImageData = useState<<buffer?>>(nil)

	-- Download image from web
	local downloadThread = useRef<<thread?>>(nil)
	useEffect(function()
		if downloadThread.current then
			pcall(task.cancel, downloadThread.current)
		end

		downloadThread.current = task.spawn(function()
			local success, result = pcall(function()
				return HttpService:RequestAsync({
					Url = url,
					Method = "GET",
					Compress = Enum.HttpCompression.Gzip,
				})
			end)

			if not success then
				Logger:Warn("Failed to download web image (network error)", {
					result = result,
				})
				return
			end

			if not result.Success then
				Logger:Warn("Failed to download web image (API error)", {
					result = result,
				})
				return
			end

			local contentType = result.Headers["content-type"] or ""
			if not string.find(contentType, "image/png", 1, true) then
				Logger:Warn("Downloaded image wasn't a PNG", {
					url = url,
					contentType = contentType,
				})
				return
			end

			-- We downloaded the image!
			setImageData(buffer.fromstring(result.Body :: string))
		end)

		return function()
			if downloadThread.current then
				pcall(task.cancel, downloadThread.current)
			end
		end
	end, { url })

	return imageData
end

return useWebImage
