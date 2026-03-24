local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local BuildVars = require(Plugin.Source.BuildVars)

local View = Foundation.View
local Text = Foundation.Text
local Badge = Foundation.Badge
local BadgeVariant = Foundation.Enums.BadgeVariant
local IconName = Foundation.Enums.IconName

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	LayoutOrder: number?,
}

local function VersionTag(props: Props)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "auto-xy row align-y-center gap-small",
		LayoutOrder = props.LayoutOrder,
	}, {
		VersionLabel = e(Text, {
			tag = "auto-xy text-label-small content-muted",
			Text = `v{BuildVars.build.version} ({BuildVars.build.hash})`,
			LayoutOrder = nextOrder(),
		}),

		DevBadge = e(Badge, {
			icon = IconName.HammerCode,
			text = "Dev Build",
			variant = BadgeVariant.Neutral,
			LayoutOrder = nextOrder(),
		}),
	})
end

return VersionTag
