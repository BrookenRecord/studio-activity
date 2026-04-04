local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local AuthStore = require(Plugin.Source.Authentication.AuthStore)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local UserSettingsStore = require(Plugin.Source.UserSettings.UserSettingsStore)

local Menu = Foundation.Menu
local IconButton = Foundation.IconButton
local IconName = Foundation.Enums.IconName
local InputSize = Foundation.Enums.InputSize

local e = React.createElement
local useState = React.useState
local useMemo = React.useMemo

type Props = {
	LayoutOrder: number?,
}

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
					print("AuthStore (WARNING contains access tokens):", auth)

					print(`\n{divider}`)

					setIsOpen(false)
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
	}, {
		DeveloperMenuButton = e(IconButton, {
			icon = IconName.HammerCode,
			size = InputSize.XSmall,
			onActivated = function()
				setIsOpen(true)
			end,
			LayoutOrder = props.LayoutOrder,
		}),
	})
end

return DeveloperMenu
