local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local AccountList = require(script.Parent.AccountList)
local Footer = require(script.Parent.Footer)
local Header = require(script.Parent.Header)
local PreviewBlock = require(script.Parent.PreviewBlock)
local ProfileSelection = require(script.Parent.ProfileSelection)

local View = Foundation.View
local ScrollView = Foundation.ScrollView
local useTokens = Foundation.Hooks.useTokens

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

local function MainScreen()
	local nextOrder = createNextOrder()
	local tokens = useTokens()

	return e(View, {
		tag = "size-full bg-surface-100 col",
	}, {
		Header = e(Header, {
			LayoutOrder = nextOrder(),
		}),

		ContentsScroller = e(ScrollView, {
			tag = "size-full-0 grow",
			scroll = {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
			},
			LayoutOrder = nextOrder(),
		}, {
			LayoutContainer = e(View, {
				tag = "size-full-0 auto-y col",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				sizeConstraint = {
					MaxSize = Vector2.new(620, math.huge),
				},
				padding = Vector2.new(0, tokens.Padding.Medium),
			}, {
				PreviewBlock = e(PreviewBlock, {
					LayoutOrder = nextOrder(),
				}),

				ProfileSelection = e(ProfileSelection, {
					LayoutOrder = nextOrder(),
				}),

				AccountList = e(AccountList, {
					LayoutOrder = nextOrder(),
				}),
			}),
		}),

		Footer = e(Footer, {
			LayoutOrder = nextOrder(),
		}),
	})
end

return React.memo(MainScreen)
