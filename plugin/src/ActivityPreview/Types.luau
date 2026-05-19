export type ActivityButton = {
	label: string,
	url: string,
}

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
	buttons: { ActivityButton }?,
	startedAt: number?,
	assets: ActivityAssets?,
}

return nil
