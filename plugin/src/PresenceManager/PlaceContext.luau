local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

local signal = Charm.signal

export type PlaceContext = {
	placeId: number?,
	placeName: string?,
	universeId: number?,
	creatorName: string?,
}

local defaultContext: PlaceContext = {
	placeId = nil,
	universeId = nil,
	creatorName = "poop!",
}

local getPlaceContext, setPlaceContext = signal(defaultContext)

return table.freeze({
	getPlaceContext = getPlaceContext,
	setPlaceContext = setPlaceContext,
})
