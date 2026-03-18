local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local QRCodeDisplay = require(Plugin.Source.QRCodeDisplay)

local View = Foundation.View
local Text = Foundation.Text
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function PhoneFlow(props: Props)
	local tokens = useTokens()
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y row gap-large align-y-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		QRCodeContainer = e(View, {
			tag = "size-2400-2400 padding-small radius-small row align-x-center align-y-center",
			backgroundStyle = tokens.LightMode.Surface.Surface_100,
			LayoutOrder = nextOrder(),
		}, {
			QRCode = e(QRCodeDisplay.QRCodeDisplay, {
				text = "https://discord.com/activate?user_code=3YEF7HKG",
				size = tokens.Size.Size_2000,
				errorCorrection = QRCodeDisplay.ErrorCorrection.Medium,
			}),
		}),

		TextBlock = e(View, {
			tag = "size-full-0 auto-y col gap-xsmall",
			LayoutOrder = nextOrder(),
		}, {
			Title = e(Text, {
				tag = "size-full-0 auto-y text-wrap text-align-x-left text-title-medium content-emphasis",
				Text = "Scan with your phone",
				LayoutOrder = nextOrder(),
			}),

			Subtitle = e(Text, {
				tag = "size-full-0 auto-y text-wrap text-align-x-left text-caption-medium content-default",
				Text = "Opens in the Discord app. Authorize there, then return to Studio.",
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return PhoneFlow
