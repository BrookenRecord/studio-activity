local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local DiscordApi = require(Plugin.Source.Api.Discord)
local DiscordAvatar = require(Plugin.Source.Common.DiscordAvatar)
local useAccountStatus = require(script.Parent.useAccountStatus)

local View = Foundation.View
local Text = Foundation.Text
local Toggle = Foundation.Toggle
local InputSize = Foundation.Enums.InputSize
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useState = React.useState

type Props = {
	user: DiscordApi.User,
	LayoutOrder: number?,
}

local function AccountEntry(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	local isActive, setActive = useState(true)
	local function toggleActive()
		setActive(function(prev)
			return not prev
		end)
	end

	local accountStore = AccountStore.get()
	local avatarImage = useSignalState(Charm.computed(function()
		local cachedImages = accountStore.cachedUserImages()
		return cachedImages[props.user.id]
	end))

	local status = useAccountStatus(isActive)

	return e(View, {
		tag = "size-full-1400 bg-shift-200 row gap-medium padding-x-medium align-y-center radius-small",
		onActivated = toggleActive,
		LayoutOrder = props.LayoutOrder,
	}, {
		Avatar = avatarImage and e(DiscordAvatar, {
			avatar = avatarImage,
			size = tokens.Size.Size_1000,
			LayoutOrder = nextOrder(),
		}),

		TextBlock = e(View, {
			tag = "size-0-full grow col gap-xxsmall align-y-center",
			LayoutOrder = nextOrder(),
		}, {
			Username = e(Text, {
				tag = "auto-xy text-label-medium content-emphasis",
				Text = props.user.username,
				LayoutOrder = nextOrder(),
			}),

			StatusBlock = e(View, {
				tag = "auto-xy row gap-xsmall align-y-center",
				LayoutOrder = nextOrder(),
			}, {
				Badge = e(View, {
					tag = "size-150-150 radius-circle",
					backgroundStyle = status.statusBadgeColor,
					LayoutOrder = nextOrder(),
				}),

				StatusText = e(Text, {
					tag = "auto-xy text-body-small",
					style = status.statusLabelColor,
					Text = status.statusLabel,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),

		ActiveToggle = e(Toggle, {
			label = "",
			isChecked = isActive,
			onActivated = toggleActive,
			size = InputSize.Small,
			LayoutOrder = nextOrder(),
		}),
	})
end

return AccountEntry
