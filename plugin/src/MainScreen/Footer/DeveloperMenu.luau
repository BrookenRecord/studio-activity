local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local AuthStore = require(Plugin.Source.Authentication.AuthStore)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local ModalStore = require(Plugin.Source.Modal.ModalStore)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local PluginStore = require(Plugin.Source.Plugin.PluginStore)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)

local Menu = Foundation.Menu
local IconButton = Foundation.IconButton
local IconName = Foundation.Enums.IconName
local InputSize = Foundation.Enums.InputSize

local STORAGE_KEYS = { "PresenceAuthStore", "PresenceLocalStorage", "PresenceUserSettings" }

type AuthStorage = AuthStore.AuthStore

local e = React.createElement
local useState = React.useState
local useMemo = React.useMemo

type Props = {
	LayoutOrder: number?,
}

local function redactAuthStore(auth: AuthStorage): AuthStorage
	local redacted: AuthStorage = {
		accounts = {},
	}

	for accountId, account in auth.accounts do
		local redactedAccount = table.clone(account)
		redactedAccount.accessToken = "<redacted>"
		redactedAccount.refreshToken = "<redacted>"
		redacted.accounts[accountId] = redactedAccount
	end

	return redacted
end

local function DeveloperMenu(props: Props)
	local isOpen, setIsOpen = useState(false)
	local items = useMemo(function(): { Foundation.MenuItems }
		return {
			{
				id = "log_storage",
				text = "Print Plugin Storage",
				onActivated = function()
					local divider = string.rep("=", 16)

					local userSettings = UserSettingsStore.get().getStorage()
					local localStorage = LocalStorageStore.get().getStorage()
					local auth = AuthStore.get().getStorage()

					print(`\n{divider}\n\nPlugin storage:\n`)

					print("UserSettings:", userSettings)
					print("LocalStorage:", localStorage)
					print("AuthStore:", redactAuthStore(auth))

					print(`\n{divider}`)

					setIsOpen(false)
				end,
			},
			{
				id = "clear_storage",
				text = "Clear All Saved Data",
				onActivated = function()
					setIsOpen(false)

					task.spawn(function()
						local confirmed = ModalStore.get().openAsync("confirmation", {
							props = {
								title = "Clear all saved data?",
								body = "This will remove all linked accounts, settings, and cached data. The plugin will need to be reloaded.",
							},
						})

						if not confirmed then
							return
						end

						local plugin = PluginStore.get().getPlugin()
						if not plugin then
							return
						end

						for _, key in STORAGE_KEYS do
							pcall(plugin.SetSetting, plugin, key, nil)
						end

						NotificationStore.get().push("info", "All saved data cleared — reload the plugin")
					end)
				end,
			},
		}
	end, {})

	return e(Menu, {
		isOpen = isOpen,
		items = items :: any,
		size = InputSize.Small,
		onPressedOutside = function()
			setIsOpen(false)
		end,
		onActivated = function()
			setIsOpen(false)
		end,
		LayoutOrder = props.LayoutOrder,
	}, {
		DeveloperMenuButton = e(IconButton, {
			icon = IconName.HammerCode,
			size = InputSize.XSmall,
			onActivated = function()
				setIsOpen(true)
			end,
		}),
	})
end

return DeveloperMenu
