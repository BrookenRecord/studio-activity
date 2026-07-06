local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local Logger = require(Plugin.Source.Logger)

local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

export type WebImageState =
	| {
		status: "loading",
		data: nil,
		url: string,
	}
	| {
		status: "ready",
		data: buffer,
		url: string,
	}
	| {
		status: "error",
		data: nil,
		url: string,
	}

local function useWebImage(url: string): WebImageState
	local imageState, setImageState = useState<<WebImageState>>({
		status = "loading",
		data = nil,
		url = url,
	})

	-- Download image from web
	local downloadThread = useRef<<thread?>>(nil)
	useEffect(function()
		if downloadThread.current then
			pcall(task.cancel, downloadThread.current)
		end

		setImageState({
			status = "loading",
			data = nil,
			url = url,
		})

		local isCurrent = true
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
				if isCurrent then
					setImageState({
						status = "error",
						data = nil,
						url = url,
					})
				end
				return
			end

			if not result.Success then
				Logger:Warn("Failed to download web image (API error)", {
					result = result,
				})
				if isCurrent then
					setImageState({
						status = "error",
						data = nil,
						url = url,
					})
				end
				return
			end

			local contentType = result.Headers["content-type"] or ""
			if not string.find(string.lower(contentType), "image/png", 1, true) then
				Logger:Warn("Downloaded image wasn't a PNG", {
					url = url,
					contentType = contentType,
				})
				if isCurrent then
					setImageState({
						status = "error",
						data = nil,
						url = url,
					})
				end
				return
			end

			if isCurrent then
				setImageState({
					status = "ready",
					data = buffer.fromstring(result.Body :: string),
					url = url,
				})
			end
		end)

		return function()
			isCurrent = false
			if downloadThread.current then
				pcall(task.cancel, downloadThread.current)
			end
		end
	end, { url })

	if imageState.url ~= url then
		return {
			status = "loading",
			data = nil,
			url = url,
		}
	end

	return imageState
end

return useWebImage
