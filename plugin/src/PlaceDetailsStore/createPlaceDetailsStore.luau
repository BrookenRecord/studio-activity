local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local Logger = require(Plugin.Source.Logger)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local RetryBackoff = require(Plugin.Source.Api.RetryBackoff)

local signal = Charm.signal
local computed = Charm.computed

local MAX_RETRIES = 3
local THUMBNAILS_API_URL = "https://thumbnails.roproxy.com/v1/batch"

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

export type PlaceEntry = {
	status: Status,
	details: OnlinePlaceDetails?,
	experienceId: number?,
	error: string?,
}

export type PlaceDetailsStore = {
	getContextByPlaceId: (placeId: number) -> PlaceContext?,
	getCurrentContext: () -> PlaceContext?,
	getPlaceEntry: (placeId: number) -> PlaceEntry?,
	prefetchPlaceIds: (placeIds: { number }, options: { showNotification: boolean? }?) -> (),
	destroy: () -> (),
}

local function decodeThumbnailResponse(body: string): string?
	local decodeSuccess, decoded = pcall(HttpService.JSONDecode, HttpService, body)
	if not decodeSuccess then
		Logger:Warn(`PlaceDetailsStore: failed to decode icon thumbnail response: {decoded}`)
		return nil
	end

	local data = decoded.data
	if not data or #data == 0 then
		Logger:Warn("PlaceDetailsStore: icon thumbnail response contained no data")
		return nil
	end

	local entry = data[1]
	if entry.state and entry.state ~= "Completed" then
		Logger:Warn(`PlaceDetailsStore: icon thumbnail entry state was {entry.state}`)
		return nil
	end

	local imageUrl = entry.imageUrl
	if not imageUrl or imageUrl == "" then
		Logger:Warn("PlaceDetailsStore: icon thumbnail entry had no imageUrl")
		return nil
	end

	return imageUrl
end

--[[
	Best-effort fetch of the place icon CDN URL from the Roblox thumbnails API.
	Returns nil on any failure so it doesn't block the rest of the details.
]]
local function fetchIconWebUrlAsync(placeId: number): string?
	local payload = {
		{
			requestId = tostring(placeId),
			type = "PlaceIcon",
			targetId = placeId,
			size = "512x512",
			format = "Png",
			isCircular = false,
		},
	}

	local success, result = pcall(function()
		return HttpService:RequestAsync({
			Url = THUMBNAILS_API_URL,
			Method = "POST",
			Compress = Enum.HttpCompression.None,
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if not success then
		Logger:Warn(`PlaceDetailsStore: icon thumbnail request failed: {result}`)
		return nil
	end

	if not result.Success then
		Logger:Warn(`PlaceDetailsStore: icon thumbnail API returned {result.StatusCode}`)
		return nil
	end

	return decodeThumbnailResponse(result.Body :: string)
end

--[[
	Fetches online place details with exponential backoff retry.
	Returns nil on persistent failure after MAX_RETRIES attempts.
]]
local function fetchOnlineDetailsWithRetryAsync(placeId: number): (OnlinePlaceDetails?, number?, string?)
	local backoffConfig = RetryBackoff.defaultConfig()
	local backoffState = RetryBackoff.createState()

	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfoAsync(placeId)
		end)

		if success then
			local productInfo = result
			local creator = productInfo.Creator
			local creatorType: "user" | "group" = if creator and creator.CreatorType == "Group" then "group" else "user"
			local creatorId = if creator then creator.CreatorTargetId else 0

			local creatorLink: string = if creatorType == "group"
				then `https://www.roblox.com/groups/{creatorId}`
				else `https://www.roblox.com/users/{creatorId}/profile`

			local iconWebUrl = fetchIconWebUrlAsync(placeId)

			local experienceId = if productInfo.UniverseId then productInfo.UniverseId else 0

			return {
				placeName = productInfo.Name,
				placeLink = `https://www.roblox.com/games/{placeId}`,

				creatorName = if creator then creator.Name else "",
				creatorType = creatorType,
				creatorLink = creatorLink,

				iconThumbnail = `rbxthumb://type=PlaceIcon&id={placeId}&w=512&h=512`,
				iconWebUrl = iconWebUrl,
			},
				experienceId,
				nil
		end

		if attempt == MAX_RETRIES then
			Logger:Warn(`PlaceDetailsStore: fetch failed after {MAX_RETRIES} attempts: {result}`)
			return nil, nil, tostring(result)
		end

		local delay = RetryBackoff.nextAttempt(backoffConfig, backoffState)
		Logger:Warn(
			`PlaceDetailsStore: fetch error, retrying in {string.format("%.1f", delay)}s (attempt {attempt}/{MAX_RETRIES}): {result}`
		)
		task.wait(delay)
	end

	return nil, nil, "unknown_error"
end

local function createPlaceDetailsStore(): PlaceDetailsStore
	local getEntries, setEntries = signal({} :: { [number]: PlaceEntry })
	local fetchThreads: { [number]: thread } = {}

	local function setEntry(placeId: number, entry: PlaceEntry)
		setEntries(function(prev)
			local new = table.clone(prev)
			new[placeId] = entry
			return new
		end)
	end

	local function getPlaceEntry(placeId: number): PlaceEntry?
		local entries = getEntries()
		return entries[placeId]
	end

	local function ensurePlaceEntry(placeId: number, showNotification: boolean)
		if placeId <= 0 then
			return
		end

		local entry = getPlaceEntry(placeId)
		if entry and (entry.status == "loading" or entry.status == "ready") then
			return
		end

		setEntry(placeId, {
			status = "loading",
		})

		if fetchThreads[placeId] then
			pcall(task.cancel, fetchThreads[placeId])
		end

		Logger:Info(`PlaceDetailsStore: fetching details for place {placeId}`)
		fetchThreads[placeId] = task.spawn(function()
			local details, experienceId, errorMessage = fetchOnlineDetailsWithRetryAsync(placeId)
			if details then
				setEntry(placeId, {
					status = "ready",
					details = details,
					experienceId = experienceId,
				})
				Logger:Info(`PlaceDetailsStore: successfully fetched details for "{details.placeName}"`)
			else
				setEntry(placeId, {
					status = "error",
					error = errorMessage,
				})
				if showNotification then
					NotificationStore.get().push("error", "Failed to load place details")
				end
			end

			fetchThreads[placeId] = nil
		end)
	end

	local function prefetchPlaceIds(placeIds: { number }, options: { showNotification: boolean? }?)
		local showNotification = if options and options.showNotification then true else false

		for _, placeId in placeIds do
			if placeId and placeId > 0 then
				ensurePlaceEntry(placeId, showNotification)
			end
		end
	end

	local function getContextByPlaceId(placeId: number): PlaceContext?
		if placeId <= 0 then
			return nil
		end

		local entry = getPlaceEntry(placeId)
		if not entry or entry.status ~= "ready" or not entry.details then
			return nil
		end

		return {
			placeType = "online",
			placeId = placeId,
			experienceId = entry.experienceId or 0,
			onlinePlaceDetails = entry.details,
		}
	end

	local currentPlaceId = game.PlaceId
	local getCurrentContext = computed(function(): PlaceContext?
		if currentPlaceId == 0 then
			return {
				placeType = "offline",
				placeId = 0,
				experienceId = 0,
				offlinePlaceDetails = {
					placeName = game.Name,
				},
			}
		end

		return getContextByPlaceId(currentPlaceId)
	end)

	if currentPlaceId > 0 then
		prefetchPlaceIds({ currentPlaceId }, {
			showNotification = true,
		})
	end

	local function destroy()
		for placeId, thread in fetchThreads do
			pcall(task.cancel, thread)
			fetchThreads[placeId] = nil
		end
	end

	return {
		getContextByPlaceId = getContextByPlaceId,
		getCurrentContext = getCurrentContext :: any,
		getPlaceEntry = getPlaceEntry,
		prefetchPlaceIds = prefetchPlaceIds,
		destroy = destroy,
	}
end

return createPlaceDetailsStore
