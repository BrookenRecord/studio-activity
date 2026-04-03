local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ModalStore = require(Plugin.Source.Modal.ModalStore)

local View = Foundation.View
local Text = Foundation.Text
local Button = Foundation.Button
local ButtonVariant = Foundation.Enums.ButtonVariant
local IconName = Foundation.Enums.IconName
local InputSize = Foundation.Enums.InputSize

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function NoneLinkedBlock(props: Props)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "bg-shift-100 size-full-0 auto-y col gap-medium align-x-center align-y-center padding-xlarge stroke-standard stroke-muted radius-small",
		LayoutOrder = props.LayoutOrder,
	}, {
		TextBlock = e(View, {
			tag = "auto-xy col gap-xsmall",
			LayoutOrder = nextOrder(),
		}, {
			Title = e(Text, {
				tag = "size-full-0 auto-y text-title-medium content-emphasis text-wrap text-align-x-center",
				Text = "Show what you're working on",
				LayoutOrder = nextOrder(),
			}),

			Subtitle = e(Text, {
				tag = "size-full-0 auto-y text-body-small content-default text-wrap text-align-x-center",
				Text = "Link your Discord account to display Studio activity on your profile.",
				LayoutOrder = nextOrder(),
			}),
		}),

		CtaBtn = e(Button, {
			text = "Link Discord Account",
			icon = IconName.Discord,
			variant = ButtonVariant.SoftEmphasis,
			size = InputSize.Small,
			onActivated = function()
				local modalStore = ModalStore.get()
				modalStore.open("addAccount")
			end,
			LayoutOrder = nextOrder(),
		}),
	})
end

return NoneLinkedBlock
