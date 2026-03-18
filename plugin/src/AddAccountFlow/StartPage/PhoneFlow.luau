local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local AuthContext = require(script.Parent.Parent.AuthContext)
local QRCode = require(Plugin.Source.QRCode)

local View = Foundation.View
local Text = Foundation.Text
local Loading = Foundation.Loading
local Icon = Foundation.Icon
local IconName = Foundation.Enums.IconName
local IconSize = Foundation.Enums.IconSize
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function PhoneFlow(props: Props)
	local tokens = useTokens()
	local nextOrder = createNextOrder()
	local auth = AuthContext.useAuth()

	local status = useSignalState(auth.deviceCodeFlow.status)
	local errorText = useSignalState(auth.deviceCodeFlow.error)
	local sessionInfo = useSignalState(auth.deviceCodeFlow.sessionInfo)

	return e(View, {
		tag = "size-full-0 auto-y row gap-large align-y-center",
		LayoutOrder = props.LayoutOrder,
	}, {
		QRCodeContainer = e(View, {
			tag = "size-2400-2400 padding-small radius-small row align-x-center align-y-center",
			backgroundStyle = tokens.LightMode.Surface.Surface_100,
			LayoutOrder = nextOrder(),
		}, {
			Loading = (status == "requesting") and e(Loading, {
				size = IconSize.Small,
			}),

			ErrorIcon = (status == "error") and e(Icon, {
				name = IconName.X,
				size = IconSize.Large,
			}),

			QRCode = (status == "polling" and sessionInfo) and e(QRCode.QRCodeDisplay, {
				text = sessionInfo.verificationUrlComplete,
				size = tokens.Size.Size_2000,
				errorCorrection = QRCode.ErrorCorrection.Medium,
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
				tag = {
					["size-full-0 auto-y text-wrap text-align-x-left text-caption-medium"] = true,
					["content-default"] = status ~= "error",
					["content-alert"] = status == "error",
				},
				Text = if status == "error"
					then `We ran into an issue: {errorText}`
					else "Opens in the Discord app. Authorize there, then return to Studio.",
				LayoutOrder = nextOrder(),
			}),
		}),
	})
end

return PhoneFlow
