local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local BrowserFlow = require(script.Parent.BrowserFlow)
local Divider = require(script.Parent.Divider)
local PhoneFlow = require(script.Parent.PhoneFlow)
local StatusUpdate = require(script.Parent.StatusUpdate)

local View = Foundation.View

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function StartPage(props: Props)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y col gap-medium",
		LayoutOrder = props.LayoutOrder,
	}, {
		BrowserFlow = e(BrowserFlow, {
			LayoutOrder = nextOrder(),
		}),

		Divider1 = e(Divider, {
			label = "OR",
			LayoutOrder = nextOrder(),
		}),

		PhoneFlow = e(PhoneFlow, {
			LayoutOrder = nextOrder(),
		}),

		Divider2 = e(Divider, {
			LayoutOrder = nextOrder(),
		}),

		StatusUpdate = e(StatusUpdate, {
			LayoutOrder = nextOrder(),
		}),
	})
end

return StartPage
