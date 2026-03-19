local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local AuthContext = require(script.Parent.Parent.AuthContext)
local DiscordAvatar = require(Plugin.Source.Common.DiscordAvatar)

local View = Foundation.View
local Text = Foundation.Text

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function ConfirmationPage(props: Props): React.ReactNode
	local nextOrder = createNextOrder()
	local auth = AuthContext.useAuth()

	local accountStore = AccountStore.get()
	local images = ReactCharm.useSignalState(accountStore.cachedUserImages)
	local users = ReactCharm.useSignalState(accountStore.cachedUsers)

	local firstImage
	for _, image in images do
		firstImage = image
		break
	end

	local firstAccount
	for _, user in users do
		firstAccount = user
		break
	end

	if firstImage == nil or firstAccount.status ~= "ready" then
		return nil
	end

	return e(View, {
		tag = "size-full-0 auto-y col gap-medium",
		LayoutOrder = props.LayoutOrder,
	}, {
		Label = e(Text, {
			tag = "auto-xy text-label-medium content-default",
			Text = `Authorized to: {firstAccount.details.globalName} (@{firstAccount.details.username})`,
		}),

		Avatar = e(DiscordAvatar, {
			avatar = firstImage,
			LayoutOrder = nextOrder(),
		}),
	})
end

return ConfirmationPage
