local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ActivityPreview = require(Plugin.Source.ActivityPreview)
local Flags = require(Plugin.Source.Flags)

local View = Foundation.View
local Text = Foundation.Text
local Toggle = Foundation.Toggle
local IconButton = Foundation.IconButton
local InputSize = Foundation.Enums.InputSize
local InputPlacement = Foundation.Enums.InputPlacement
local IconName = Foundation.Enums.IconName

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement
local useState = React.useState

type Props = {
	LayoutOrder: number?,
}

local function PreviewBlock(props: Props)
	local nextOrder = createNextOrder()

	local isExpanded, setExpanded = useState(true)

	return e(View, {
		tag = "size-full-0 auto-y bg-surface-200 col padding-x-large padding-y-medium gap-medium",
		LayoutOrder = props.LayoutOrder,
	}, {
		Shadow = Flags.isShadowAvailable and e("UIShadow", {
			Transparency = 0.85,
			BlurRadius = UDim.new(0, 16),
		}),

		HeaderBlock = e(View, {
			tag = "size-full-0 auto-y row align-y-center gap-medium",
			LayoutOrder = nextOrder(),
		}, {
			Title = e(Text, {
				tag = "auto-y grow text-align-x-left text-title-small content-muted",
				Text = "Live Preview",
				LayoutOrder = nextOrder(),
			}),

			ActiveToggle = e(Toggle, {
				label = "Active",
				isChecked = true,
				onActivated = function()
					print("Toggle switch activated")
				end,
				size = InputSize.Small,
				placement = InputPlacement.End,
				LayoutOrder = nextOrder(),
			}),

			ExpandToggle = e(IconButton, {
				icon = if isExpanded then IconName.ChevronSmallDown else IconName.ChevronSmallUp,
				size = InputSize.XSmall,
				onActivated = function()
					setExpanded(function(prev)
						return not prev
					end)
				end,
				LayoutOrder = nextOrder(),
			}),
		}),

		Preview = isExpanded and e(ActivityPreview, {
			activity = {
				name = "Roblox Studio 1",
				details = "Roblox Studio 2",
				state = "Roblox Studio 3",
				assets = {
					largeImage = "",
					largeText = "Editing in Roblox Studio",

					smallImage = "",
					smallText = "Lorem Ipsum",
				},
			},
			LayoutOrder = nextOrder(),
		}),
	})
end

return PreviewBlock
