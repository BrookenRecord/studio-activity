local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local Logger = require(Plugin.Source.Logger)
local RetryBackoff = require(Plugin.Source.Api.RetryBackoff)

local signal = Charm.signal
local computed = Charm.computed
local effect = Charm.effect

local MAX_RETRIES = 3

-- We use `roproxy` as a Roblox API proxy, because plugins can't make API
-- requests directly to Roblox resources. Later on we probably want to move this
-- fetch to our own backend to avoid the third-party dependency that we don't
-- control.
local THUMBNAILS_API_FORMAT =
	"https://thumbnails.roproxy.com/v1/games/icons?universeIds=%d&returnPolicy=PlaceHolder&size=512x512&format=Png&isCircular=false"

export type PlaceType = "offline" | "online"
export type Status = "ready" | "error" | "loading"

export type OnlinePlaceDetails = {
	placeName: string,
	placeLink: string,

	creatorName: string,
	creatorType: "user" | "group",
	creatorLink: string,

	iconThumbnail: string,
	iconWebUrl: string?,
}

export type OfflinePlaceDetails = {
	placeName: string,
}

export type PlaceContext = {
	placeType: PlaceType,
	placeId: number,
	experienceId: number,

	onlinePlaceDetails: OnlinePlaceDetails?,
	offlinePlaceDetails: OfflinePlaceDetails?,
}

export type PlaceContextStore = {
	getStatus: () -> Status,
	getContext: () -> PlaceContext?,
	refresh: () -> (),
	destroy: () -> (),
}

--[[
	Best-effort fetch of the game icon CDN URL from the Roblox thumbnails API.
	Returns nil on any failure so it doesn't block the rest of the details.
]]
local function fetchIconWebUrlAsync(experienceId: number): string?
	local url = string.format(THUMBNAILS_API_FORMAT, experienceId)

	local success, result = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Compress = Enum.HttpCompression.None,
		})
	end)

	if not success then
		Logger:Warn(`PlaceContextStore: icon thumbnail request failed: {result}`)
		return nil
	end

	if not result.Success then
		Logger:Warn(`PlaceContextStore: icon thumbnail API returned {result.StatusCode}`)
		return nil
	end

	local decodeSuccess, body = pcall(HttpService.JSONDecode, HttpService, result.Body :: string)
	if not decodeSuccess then
		Logger:Warn(`PlaceContextStore: failed to decode icon thumbnail response: {body}`)
		return nil
	end

	local data = body.data
	if not data or #data == 0 then
		Logger:Warn("PlaceContextStore: icon thumbnail response contained no data")
		return nil
	end

	local imageUrl = data[1].imageUrl
	if not imageUrl or imageUrl == "" then
		Logger:Warn("PlaceContextStore: icon thumbnail entry had no imageUrl")
		return nil
	end

	return imageUrl
end

--[[
	Fetches online place details with exponential backoff retry.
	Returns nil on persistent failure after MAX_RETRIES attempts.
]]
local function fetchOnlineDetailsWithRetryAsync(placeId: number, experienceId: number): OnlinePlaceDetails?
	local backoffConfig = RetryBackoff.defaultConfig()
	local backoffState = RetryBackoff.createState()

	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfoAsync(placeId)
		end)

		if success then
			local productInfo = result

			local creatorType: "user" | "group" = if productInfo.Creator.CreatorType == "Group" then "group" else "user"

			local creatorLink: string = if creatorType == "group"
				then `https://www.roblox.com/groups/{productInfo.Creator.CreatorTargetId}`
				else `https://www.roblox.com/users/{productInfo.Creator.CreatorTargetId}/profile`

			local iconWebUrl = fetchIconWebUrlAsync(experienceId)

			return {
				placeName = productInfo.Name,
				placeLink = `https://www.roblox.com/games/{placeId}`,

				creatorName = productInfo.Creator.Name,
				creatorType = creatorType,
				creatorLink = creatorLink,

				iconThumbnail = `rbxthumb://type=GameIcon&id={experienceId}&w=512&h=512`,
				iconWebUrl = iconWebUrl,
			}
		end

		if attempt == MAX_RETRIES then
			Logger:Warn(`PlaceContextStore: fetch failed after {MAX_RETRIES} attempts: {result}`)
			return nil
		end

		local delay = RetryBackoff.nextAttempt(backoffConfig, backoffState)
		Logger:Warn(
			`PlaceContextStore: fetch error, retrying in {string.format("%.1f", delay)}s (attempt {attempt}/{MAX_RETRIES}): {result}`
		)
		task.wait(delay)
	end

	return nil
end

--[[
	This store manages context about the Place we're currently editing. It
	handles data fetching for place data, tracking which scripts are open, etc.
]]
local function createPlaceContextStore(): PlaceContextStore
	-- TODO: I don't think this can ever change without the whole plugin
	-- reloading, but we're setup in case it actually can. Need to track if
	-- it does change, though.
	local getPlaceId, _setPlaceId = signal(game.PlaceId)

	-- Luau types are weird here
	local getPlaceType: () -> PlaceType = computed(function(): any
		return if getPlaceId() == 0 then "offline" else "online"
	end)

	local getStatus, setStatus = signal<<Status>>("loading")

	-- Bumped to trigger a re-fetch from the UI (e.g. a "retry" button)
	local getRefreshVersion, setRefreshVersion = signal(0)

	-- We have to dynamically fetch details for the online experience
	local fetchOnlineDetailsThread: thread?
	local getOnlinePlaceDetails, setOnlinePlaceDetails = signal<<OnlinePlaceDetails?>>(nil)

	local disposeOnlineFetchEffect = effect(function()
		local placeType: PlaceType = getPlaceType()
		local placeId = getPlaceId()
		local _version = getRefreshVersion()

		if fetchOnlineDetailsThread ~= nil then
			pcall(task.cancel, fetchOnlineDetailsThread)
		end

		if placeType == "offline" then
			setOnlinePlaceDetails(nil)
			setStatus("ready")
			return
		end

		setStatus("loading")
		Logger:Info(`PlaceContextStore: fetching details for place {placeId}`)

		fetchOnlineDetailsThread = task.spawn(function()
			local experienceId = game.GameId
			local details = fetchOnlineDetailsWithRetryAsync(placeId, experienceId)

			if details then
				setOnlinePlaceDetails(details)
				setStatus("ready")
				Logger:Info(`PlaceContextStore: successfully fetched details for "{details.placeName}"`)
			else
				setOnlinePlaceDetails(nil)
				setStatus("error")
			end

			fetchOnlineDetailsThread = nil
		end)
	end)

	-- Thankfully, offline place details is much simpler. Nothing is async.
	local getOfflinePlaceDetails = computed(function(): OfflinePlaceDetails?
		local placeType: PlaceType = getPlaceType()
		if placeType ~= "offline" then
			return nil
		end

		return {
			-- In a local file, this corresponds to the file name
			placeName = game.Name,
		}
	end)

	-- Compose the final PlaceContext from sub-signals.
	local getContext: () -> PlaceContext? = computed(function(): any
		local placeType: PlaceType = getPlaceType()
		local placeId = getPlaceId()

		if placeType == "offline" then
			return {
				placeType = placeType,
				placeId = placeId,
				experienceId = 0,
				offlinePlaceDetails = getOfflinePlaceDetails(),
			}
		end

		local online = getOnlinePlaceDetails()
		if not online then
			return nil
		end

		return {
			placeType = placeType,
			placeId = placeId,
			experienceId = game.GameId,
			onlinePlaceDetails = online,
		}
	end)

	local function refresh()
		setRefreshVersion(function(prev: number)
			return prev + 1
		end)
	end

	local function destroy()
		disposeOnlineFetchEffect()

		if fetchOnlineDetailsThread then
			pcall(task.cancel, fetchOnlineDetailsThread)
			fetchOnlineDetailsThread = nil
		end
	end

	return {
		getStatus = getStatus,
		getContext = getContext,
		refresh = refresh,
		destroy = destroy,
	}
end

return createPlaceContextStore
