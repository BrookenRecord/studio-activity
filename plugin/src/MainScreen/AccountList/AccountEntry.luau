local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local DiscordAvatar = require(Plugin.Source.Common.DiscordAvatar)
local ModalStore = require(Plugin.Source.Modal.ModalStore)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local PresenceManager = require(Plugin.Source.PresenceManager)
local useAccountStatus = require(script.Parent.useAccountStatus)

local createAccountStore = require(Plugin.Source.Authentication.AccountStore.createAccountStore)
type LocalUser = createAccountStore.LocalUser

local View = Foundation.View
local Text = Foundation.Text
local Button = Foundation.Button
local IconButton = Foundation.IconButton
local Toggle = Foundation.Toggle
local Skeleton = Foundation.Skeleton
local Menu = Foundation.Menu
local ButtonVariant = Foundation.Enums.ButtonVariant
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName
local Radius = Foundation.Enums.Radius
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder
local useToggleState = ReactUtils.useToggleState
local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useCallback = React.useCallback
local useMemo = React.useMemo

type Props = {
	accountId: string,
	localUser: LocalUser,
	LayoutOrder: number?,
}

local function AccountEntry(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()
	local user = props.localUser

	local presenceManager = PresenceManager.get()
	local disabledIds = useSignalState(presenceManager.getDisabledAccountIds)
	local isActive = not disabledIds[props.accountId]

	local toggleActive = useCallback(function()
		presenceManager.setAccountActive(props.accountId, not isActive)
	end, { presenceManager :: any, props.accountId, isActive })

	local accountStore = AccountStore.get()
	local avatarImage = useSignalState(Charm.computed(function()
		local cachedImages = accountStore.cachedUserImages()
		return cachedImages[props.accountId]
	end))

	local status = useAccountStatus(isActive, user)
	local details = if user.status == "ready"
		then user.details
		elseif user.status == "error" then user.cachedDetails
		else nil

	local menuState = useToggleState(false)
	local menuItems = useMemo(function(): Foundation.MenuItems
		return {
			{
				id = "remove",
				icon = IconName.TrashCan,
				text = "Disconnect Account",
				onActivated = function()
					menuState.disable()

					-- Get confirmation before disconnecting the account
					local modalStore = ModalStore.get()
					task.spawn(function()
						local result = modalStore.openAsync("confirmation", {
							props = {
								title = "Are you sure?",
								body = "If you disconnect the account, you'll have to re-link it.",
							},
						})

						if result then
							accountStore.removeUser(props.accountId)

							local username = if details then details.username else nil
							NotificationStore.get()
								.push("info", if username then `Disconnected account {username}` else "Disconnected account")
						end
					end)
				end,
			},
		}
	end, { menuState.disable :: any, details })

	local isDisabled = user.status ~= "ready"
	local isLoading = user.status == "loading"
	local isError = user.status == "error"

	return e(View, {
		tag = "bg-shift-200 size-full-1400 row gap-medium padding-x-medium align-y-center radius-small",
		onActivated = if not isDisabled then toggleActive else nil,
		onSecondaryActivated = if not isDisabled then menuState.toggle else nil,
		stroke = if user.status == "error"
			then {
				Color = tokens.Color.System.Alert.Color3,
				Thickness = tokens.Stroke.Standard,
				Transparency = 0.4,
			}
			else nil,
		LayoutOrder = props.LayoutOrder,
	}, {
		Avatar = avatarImage and e(DiscordAvatar, {
			avatar = avatarImage,
			size = tokens.Size.Size_1000,
			isDimmed = isDisabled,
			LayoutOrder = nextOrder(),
		}),

		TextBlock = e(View, {
			tag = "size-0-full grow col gap-xxsmall align-y-center",
			LayoutOrder = nextOrder(),
		}, {
			Username = if isLoading
				then e(Skeleton, {
					Size = UDim2.new(0.4, 0, 0, 12),
					radius = Radius.XSmall,
					LayoutOrder = nextOrder(),
				})
				else e(Text, {
					tag = "auto-xy text-label-medium content-emphasis",
					Text = if details then details.username else "Unknown user",
					LayoutOrder = nextOrder(),
				}),

			StatusBlock = if isLoading
				then e(Skeleton, {
					Size = UDim2.new(0.5, 0, 0, 10),
					radius = Radius.XSmall,
					LayoutOrder = nextOrder(),
				})
				else e(View, {
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
						textStyle = status.statusLabelColor,
						Text = status.statusLabel,
						LayoutOrder = nextOrder(),
					}),
				}),
		}),

		RegularControls = (not isError) and e(View, {
			tag = "auto-xy row align-y-center gap-small",
			LayoutOrder = nextOrder(),
		}, {
			ActiveToggle = e(Toggle, {
				label = "",
				isChecked = isActive,
				isDisabled = isDisabled,
				onActivated = toggleActive,
				size = InputSize.Small,
				LayoutOrder = nextOrder(),
			}),

			Menu = e(Menu, {
				isOpen = menuState.enabled,
				items = menuItems,
				size = InputSize.Small,
				onPressedOutside = menuState.disable,
				onActivated = menuState.disable,
				LayoutOrder = nextOrder(),
			}, {
				MenuBtn = e(IconButton, {
					icon = IconName.ThreeDotsHorizontal,
					size = InputSize.Small,
					onActivated = menuState.toggle,
				}),
			}),
		}),

		ErrorControls = isError and e(View, {
			tag = "auto-xy row align-y-center gap-xsmall",
			LayoutOrder = nextOrder(),
		}, {
			RelinkAccount = e(Button, {
				text = "Re-link",
				variant = ButtonVariant.Utility,
				size = InputSize.Small,
				onActivated = function() end,
				LayoutOrder = nextOrder(),
			}),

			DeleteAccount = e(IconButton, {
				icon = IconName.TrashCan,
				variant = ButtonVariant.Utility,
				size = InputSize.Small,
				onActivated = function()
					accountStore.removeUser(props.accountId)
				end,
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return React.memo(AccountEntry)
