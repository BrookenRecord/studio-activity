local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local BackendApi = require(Plugin.Source.Api.Backend)
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

	local updateAvailable, setUpdateAvailable = React.useState(false)

	React.useEffect(function()
		-- Don't pester developers with update prompts for their own dev builds.
		if BuildVars.build.isDev then
			return
		end

		local cancelled = false

		task.spawn(function()
			local backend = BackendApi.new(BuildVars.api)
			local result = backend.getLatestVersionAsync()
			if cancelled or not result.ok then
				return
			end

			if result.value.version ~= BuildVars.build.version then
				setUpdateAvailable(true)
			end
		end)

		return function()
			cancelled = true
		end
	end, {})

	return e(View, {
		tag = "auto-xy row align-y-center gap-small",
		LayoutOrder = props.LayoutOrder,
	}, {
		VersionLabel = e(Text, {
			tag = "auto-xy text-label-small content-muted",
			Text = `v{BuildVars.build.version} ({BuildVars.build.hash})`,
			LayoutOrder = nextOrder(),
		}),

		DevBadge = BuildVars.build.isDev and e(Badge, {
			icon = IconName.HammerCode,
			text = "Dev Build",
			variant = BadgeVariant.Neutral,
			LayoutOrder = nextOrder(),
		}),

		UpdateBadge = updateAvailable and e(Badge, {
			icon = IconName.CloudArrowDown,
			text = "Update Available",
			variant = BadgeVariant.Warning,
			LayoutOrder = nextOrder(),
		}),
	})
end

return VersionTag
