local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local PluginWordmark = require(Plugin.Source.Common.PluginWordmark)
local PresenceManager = require(Plugin.Source.PresenceManager)
local Telemetry = require(Plugin.Source.Telemetry.fireEventAsync)
local Types = require(Plugin.Source.Telemetry.Types)

local View = Foundation.View
local Text = Foundation.Text
local Toggle = Foundation.Toggle
local InputSize = Foundation.Enums.InputSize
local InputPlacement = Foundation.Enums.InputPlacement
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useCallback = React.useCallback

type Props = {
	LayoutOrder: number?,
}

local function Header(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	local presenceManager = PresenceManager.get()
	local isActive = useSignalState(presenceManager.getIsActive)

	local toggleActive = useCallback(function()
		local newState = not presenceManager.getIsActive()
		presenceManager.setIsActive(newState)
		Telemetry.fireEvent({
			type = "presenceToggled",
			value = Types.PresenceToggled.new({ isActive = newState }),
		})
	end, { presenceManager })

	return e(View, {
		tag = "size-full-0 auto-y bg-surface-100 col gap-medium",
		LayoutOrder = props.LayoutOrder,
		ZIndex = 2,
	}, {
		LayoutBlock = e(View, {
			tag = "size-full-0 auto-y row align-y-center padding-x-large padding-top-medium gap-medium",
			LayoutOrder = nextOrder(),
		}, {
			Wordmark = e(PluginWordmark, {
				size = "small",
				LayoutOrder = nextOrder(),
			}),

			Title = e(Text, {
				tag = "auto-y grow text-align-x-left text-title-small content-muted",
				Text = "",
				LayoutOrder = nextOrder(),
			}),

			ActiveToggle = e(Toggle, {
				label = if isActive then "Active" else "Inactive",
				isChecked = isActive,
				onActivated = toggleActive,
				size = InputSize.Small,
				placement = InputPlacement.End,
				LayoutOrder = nextOrder(),
			}),
		}),

		Divider = e(View, {
			backgroundStyle = tokens.Color.Stroke.Muted,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = nextOrder(),
		}),
	})
end

return React.memo(Header)
