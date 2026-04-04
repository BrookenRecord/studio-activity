local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local BuildVars = require(Plugin.Source.BuildVars)
local DeveloperMenu = require(script.Parent.DeveloperMenu)
local ModalStore = require(Plugin.Source.Modal.ModalStore)
local VersionTag = require(script.Parent.VersionTag)

local View = Foundation.View
local IconButton = Foundation.IconButton
local IconName = Foundation.Enums.IconName
local InputSize = Foundation.Enums.InputSize
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function Footer(props: Props)
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	return e(View, {
		tag = "size-full-900 bg-surface-100 col",
		LayoutOrder = props.LayoutOrder,
	}, {
		Divider = e(View, {
			backgroundStyle = tokens.Color.Stroke.Muted,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = nextOrder(),
		}),

		LayoutBlock = e(View, {
			tag = "size-full row padding-x-large",
			LayoutOrder = nextOrder(),
		}, {
			LeftBlock = e(View, {
				tag = "size-0-full grow row gap-medium align-y-center",
				LayoutOrder = nextOrder(),
			}, {
				VersionTag = e(VersionTag, {
					LayoutOrder = nextOrder(),
				}),
			}),

			RightBlock = e(View, {
				tag = "size-0-full auto-x row gap-medium align-y-center",
				LayoutOrder = nextOrder(),
			}, {
				DeveloperMenu = BuildVars.build.isDev and e(DeveloperMenu, {
					LayoutOrder = nextOrder(),
				}),

				Settings = e(IconButton, {
					icon = IconName.Gear,
					size = InputSize.XSmall,
					onActivated = function()
						ModalStore.get().open("settings")
					end,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),
	})
end

return Footer
