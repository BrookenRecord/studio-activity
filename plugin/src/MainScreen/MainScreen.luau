local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local AccountList = require(script.Parent.AccountList)
local PreviewBlock = require(script.Parent.PreviewBlock)

local View = Foundation.View

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

local function MainScreen()
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full bg-surface-100 col",
	}, {
		PreviewBlock = e(PreviewBlock, {
			LayoutOrder = nextOrder(),
		}),

		AccountList = e(AccountList, {
			LayoutOrder = nextOrder(),
		}),
	})
end

return MainScreen
