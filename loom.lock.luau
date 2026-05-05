return {
  version = 2,
  dependencies = {
    ["dotenv@v0.1.2"] = {
      installPath = "Packages/dotenv@v0.1.2",
      name = "dotenv",
      rev = "v0.1.2",
      source = "https://github.com/erlcx/lute-dotenv",
      sourceKind = "github",
      dependencies = {},
    },
    ["lute@v1.0.0"] = {
      installPath = "Packages/lute@v1.0.0",
      name = "lute",
      rev = "v1.0.0",
      source = "https://github.com/luau-lang/lute",
      sourceKind = "github",
      dependencies = {},
    },
  },
  packages = {"lute@v1.0.0", "dotenv@v0.1.2"},
}
