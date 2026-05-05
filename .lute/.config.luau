return {
	luau = {
		languagemode = "strict",
		lint = { ["*"] = true },
		linterrors = true,
		aliases = {
			batteries = "../Packages/lute@v1.0.0/batteries",
			dotenv = "../Packages/dotenv@v0.1.2/src",
			std = "~/.lute/typedefs/1.0.0/std",
		},
	},
}
