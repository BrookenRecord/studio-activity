local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local View = Foundation.View
local Text = Foundation.Text
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function StatusUpdate(props: Props)
	local tokens = useTokens()
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y row gap-small align-y-center padding-bottom-medium",
		LayoutOrder = props.LayoutOrder,
	}, {
		Pulse = e(View, {
			tag = "size-200-200 radius-circle",
			backgroundStyle = tokens.Color.System.Warning,
			LayoutOrder = nextOrder(),
		}),

		Text = e(Text, {
			tag = "auto-xy text-label-small content-muted",
			Text = "Waiting for authorization...",
			LayoutOrder = nextOrder(),
		}),
	})
end

return StatusUpdate
