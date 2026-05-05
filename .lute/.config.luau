return {
	luau = {
		languagemode = "strict",
		lint = { ["*"] = true },
		linterrors = true,
		aliases = {
			batteries = "../Packages/lute@v1.0.0/batteries",
			std = "~/.lute/typedefs/1.0.0/std",
		},
	},
}
