export type BuildVars = {
	build: {
		version: string,
		channel: string,
		hash: string,
	},

	api: {
		secure: boolean,
		host: string,
	},

	discord: {
		clientId: string,
	},
}

return nil
