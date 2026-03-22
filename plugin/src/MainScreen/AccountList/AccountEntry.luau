local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local DiscordAvatar = require(Plugin.Source.Common.DiscordAvatar)
local useAccountStatus = require(script.Parent.useAccountStatus)

local createAccountStore = require(Plugin.Source.Authentication.AccountStore.createAccountStore)
type LocalUser = createAccountStore.LocalUser

local View = Foundation.View
local Text = Foundation.Text
local Toggle = Foundation.Toggle
local Button = Foundation.Button
local Skeleton = Foundation.Skeleton
local InputSize = Foundation.Enums.InputSize
local ButtonVariant = Foundation.Enums.ButtonVariant
local Radius = Foundation.Enums.Radius
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useState = React.useState

local PROBLEM_LABELS = {
	unauthorized = "Session expired",
	network = "Network error",
	unexpected = "Unexpected error",
}

type Props = {
	accountId: string,
	localUser: LocalUser,
	LayoutOrder: number?,
}

local function AccountEntry(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()
	local localUser = props.localUser

	-- Hooks must be called unconditionally
	local isActive, setActive = useState(true)
	local function toggleActive()
		setActive(function(prev)
			return not prev
		end)
	end

	local accountStore = AccountStore.get()
	local avatarImage = useSignalState(Charm.computed(function()
		local cachedImages = accountStore.cachedUserImages()
		return cachedImages[props.accountId]
	end))

	local status = useAccountStatus(isActive)

	-- Loading state
	if localUser.status == "loading" then
		return e(View, {
			tag = "size-full-1400 bg-shift-200 row gap-medium padding-x-medium align-y-center radius-small",
			LayoutOrder = props.LayoutOrder,
		}, {
			AvatarSkeleton = e(Skeleton, {
				Size = UDim2.fromOffset(tokens.Size.Size_1000, tokens.Size.Size_1000),
				radius = Radius.Circle,
				LayoutOrder = nextOrder(),
			}),

			TextBlock = e(View, {
				tag = "size-0-full grow col gap-xxsmall align-y-center",
				LayoutOrder = nextOrder(),
			}, {
				UsernameSkeleton = e(Skeleton, {
					Size = UDim2.new(0.6, 0, 0, 14),
					radius = Radius.Small,
					LayoutOrder = nextOrder(),
				}),

				StatusSkeleton = e(Skeleton, {
					Size = UDim2.new(0.4, 0, 0, 10),
					radius = Radius.Small,
					LayoutOrder = nextOrder(),
				}),
			}),
		})
	end

	-- Error state
	if localUser.status == "error" then
		local cachedDetails = localUser.cachedDetails
		local errorLabel = PROBLEM_LABELS[localUser.problemType] or localUser.problemType

		return e(View, {
			tag = "size-full-1400 bg-shift-200 row gap-medium padding-x-medium align-y-center radius-small stroke-alert stroke-thick",
			LayoutOrder = props.LayoutOrder,
		}, {
			Avatar = cachedDetails and avatarImage and e(DiscordAvatar, {
				avatar = avatarImage,
				size = tokens.Size.Size_1000,
				LayoutOrder = nextOrder(),
			}),

			TextBlock = e(View, {
				tag = "size-0-full grow col gap-xxsmall align-y-center",
				LayoutOrder = nextOrder(),
			}, {
				Title = e(Text, {
					tag = "auto-xy text-label-medium content-emphasis",
					Text = if cachedDetails then cachedDetails.username else "Account error",
					LayoutOrder = nextOrder(),
				}),

				ErrorText = e(Text, {
					tag = "auto-xy text-body-small",
					style = tokens.Color.System.Alert,
					Text = errorLabel,
					LayoutOrder = nextOrder(),
				}),
			}),

			RelinkButton = e(Button, {
				text = "Re-link",
				variant = ButtonVariant.Alert,
				size = InputSize.Small,
				onActivated = function()
					accountStore.removeUser(props.accountId)
				end,
				LayoutOrder = nextOrder(),
			}),
		})
	end

	-- Ready state
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
				Text = localUser.details.username,
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
