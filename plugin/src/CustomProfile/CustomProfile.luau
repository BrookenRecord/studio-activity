local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ActivityFields = require(script.Parent.ActivityFields)
local GameOverride = require(script.Parent.GameOverride)
local PreviewBlock = require(script.Parent.PreviewBlock)
local ProfileActions = require(script.Parent.ProfileActions)
local ProfileContext = require(script.Parent.ProfileContext)
local ProfileName = require(script.Parent.ProfileName)
local Title = require(script.Parent.Title)

local View = Foundation.View
local Sheet = Foundation.Sheet
local DialogSize = Foundation.Enums.DialogSize

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Props = {
	isOpen: boolean,
	existingProfileId: string?,
	onClose: (result: any?) -> (),
}

local function CustomProfile(props: Props)
	local nextOrder = createNextOrder()

	local isNewProfile = props.existingProfileId == nil

	return e(ProfileContext.Provider, {
		isOpen = props.isOpen,
		existingProfileId = props.existingProfileId,
	}, {
		Sheet = e(Sheet.Root, {
			isOpen = props.isOpen,
			preferCenterSheet = true,
			snapPoints = { 0.95 },
			size = DialogSize.Medium,
			onClose = props.onClose,
		}, {
			Header = e(Sheet.Header, {
				hasCloseAffordance = true,
			}, {
				Title = e(Title, {
					isNewProfile = isNewProfile,
					LayoutOrder = nextOrder(),
				}),
			}),

			Content = e(Sheet.Content, nil, {
				Container = e(View, {
					tag = "size-full-0 auto-y col padding-y-small",
					LayoutOrder = nextOrder(),
				}, {
					PreviewBlock = e(PreviewBlock, {
						LayoutOrder = nextOrder(),
					}),

					ProfileName = e(ProfileName, {
						LayoutOrder = nextOrder(),
					}),

					ActivityFields = e(ActivityFields, {
						LayoutOrder = nextOrder(),
					}),

					GameOverride = e(GameOverride, {
						LayoutOrder = nextOrder(),
					}),
				}),
			}),

			Actions = e(ProfileActions, {
				isNewProfile = isNewProfile,
				onClose = props.onClose,
			}),
		}),
	})
end

return CustomProfile
