export type BuildVars = {
	build: {
		version: string,
		channel: string,
		target: string,
		hash: string,
		isDev: boolean,
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
