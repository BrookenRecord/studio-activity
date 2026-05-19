local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local ActivityFields = require(script.Parent.ActivityFields)
local GameOverride = require(script.Parent.GameOverride)
local ModalStore = require(Plugin.Source.Modal.ModalStore)
local PreviewBlock = require(script.Parent.PreviewBlock)
local ProfileActions = require(script.Parent.ProfileActions)
local ProfileContext = require(script.Parent.ProfileContext)
local ProfileName = require(script.Parent.ProfileName)
local Title = require(script.Parent.Title)

local View = Foundation.View
local Sheet = Foundation.Sheet
local DialogSize = Foundation.Enums.DialogSize

local createNextOrder = ReactUtils.createNextOrder
local useCallback = React.useCallback

local e = React.createElement

type Props = {
	isOpen: boolean,
	existingProfileId: string?,
	onClose: (result: any?) -> (),
}

type SheetProps = {
	isOpen: boolean,
	isNewProfile: boolean,
	onClose: (result: any?) -> (),
}

local function CustomProfileSheet(props: SheetProps)
	local nextOrder = createNextOrder()
	local profile = ProfileContext.useProfile()

	-- Wraps Sheet.Root's onClose (fired by the X button or backdrop dismiss) so
	-- we can prompt for confirmation when the user has unsaved edits. ProfileActions's
	-- Save/Delete buttons call props.onClose directly and intentionally bypass this
	-- guard because they resolve the dirty state themselves.
	--
	-- Sheet.Root also fires onClose at the end of its programmatic close
	-- animation (triggered when isOpen flips false), e.g. after the user already
	-- confirmed discard or after Delete. In that case props.isOpen is already
	-- false so we short-circuit; otherwise we'd re-prompt against the still-dirty
	-- store and pop the dialog twice.
	local handleClose = useCallback(function()
		if not props.isOpen then
			return
		end

		if not profile.profileStore.isChanged() then
			props.onClose()
			return
		end

		task.spawn(function()
			local accepted = ModalStore.get().openAsync("confirmation", {
				priority = 2,
				props = {
					title = "Discard unsaved changes?",
					body = "Your edits to this profile will be lost.",
				},
			})
			if accepted then
				props.onClose()
			end
		end)
	end, { props.isOpen, props.onClose, profile.profileStore } :: { any })

	return e(Sheet.Root, {
		isOpen = props.isOpen,
		preferCenterSheet = true,
		snapPoints = { 0.95 },
		size = DialogSize.Medium,
		onClose = handleClose,
	}, {
		Header = e(Sheet.Header, {
			hasCloseAffordance = true,
		}, {
			Title = e(Title, {
				isNewProfile = props.isNewProfile,
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
			isNewProfile = props.isNewProfile,
			onClose = props.onClose,
		}),
	})
end

local function CustomProfile(props: Props)
	local isNewProfile = props.existingProfileId == nil

	return e(ProfileContext.Provider, {
		isOpen = props.isOpen,
		existingProfileId = props.existingProfileId,
	}, {
		Sheet = e(CustomProfileSheet, {
			isOpen = props.isOpen,
			isNewProfile = isNewProfile,
			onClose = props.onClose,
		}),
	})
end

return CustomProfile
