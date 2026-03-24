export type ActivityAssets = {
	largeImage: string?,
	largeText: string?,
	smallImage: string?,
	smallText: string?,
}

export type Activity = {
	name: string,
	details: string?,
	detailsUrl: string?,
	state: string?,
	stateUrl: string?,
	startedAt: number?,
	assets: ActivityAssets?,
}

return nil
