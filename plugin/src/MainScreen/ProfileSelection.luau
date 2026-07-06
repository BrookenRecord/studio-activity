local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ModalStore = require(Plugin.Source.Modal.ModalStore)
local ProfileStore = require(Plugin.Source.PresenceManager.ProfileStore)
local Section = require(Plugin.Source.Common.Section)
local Telemetry = require(Plugin.Source.Telemetry.fireEventAsync)
local Types = require(Plugin.Source.Telemetry.Types)

local View = Foundation.View
local Dropdown = Foundation.Dropdown
local Button = Foundation.Button
local IconButton = Foundation.IconButton
local Tooltip = Foundation.Tooltip
local ButtonVariant = Foundation.Enums.ButtonVariant
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName
local IconVariant = Foundation.Enums.IconVariant
local PopoverSide = Foundation.Enums.PopoverSide
local PopoverAlign = Foundation.Enums.PopoverAlign

type IconName = Foundation.IconName

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

local CUSTOM_PROFILE_TRIGGER_ID = "__add-custom-profile"

local profileDropdownItems = Charm.computed(function(): Foundation.DropdownItems
	type Record = { id: string, name: string, icon: IconName, sortOrder: number }
	local presetProfiles: { Record } = {}
	local customProfiles: { Record } = {}

	local allProfiles = ProfileStore.get().getAllProfiles()
	for id, profile in allProfiles do
		local target: { Record } = if profile.isPreset then presetProfiles else customProfiles
		table.insert(target, {
			id = id,
			icon = profile.icon,
			name = profile.name,
			sortOrder = profile.sortOrder,
		})
	end

	-- Presets honor the order authored in presets.luau (Default before
	-- Confidential, etc.), falling back to alphabetical for ties.
	table.sort(presetProfiles, function(a, b)
		if a.sortOrder ~= b.sortOrder then
			return a.sortOrder < b.sortOrder
		end
		return a.name < b.name
	end)
	table.sort(customProfiles, function(a, b)
		return a.name < b.name
	end)

	-- Build the dropdown items list
	local presetItems: Foundation.BaseMenuItemGroup<Foundation.DropdownItem> = { items = {} }
	for _, profile in presetProfiles do
		table.insert(presetItems.items, {
			id = profile.id,
			text = profile.name,
			icon = profile.icon :: any,
		})
	end

	local customItems: Foundation.BaseMenuItemGroup<Foundation.DropdownItem>
	if #customProfiles > 0 then
		customItems = { items = {} }
		for _, profile in customProfiles do
			table.insert(customItems.items, {
				id = profile.id,
				text = profile.name,
				icon = profile.icon :: any,
			})
		end
	end

	-- Combine them
	local items: Foundation.DropdownItems = { presetItems }
	if customItems then
		table.insert(items, customItems)
	end

	-- Custom profile trigger
	table.insert(items, {
		items = {
			{
				id = CUSTOM_PROFILE_TRIGGER_ID,
				text = "New Profile",
				icon = IconName.PlusLarge,
			},
		},
	})

	return items
end)

local function isPresetProfile(): boolean
	local profileStore = ProfileStore.get()
	local activeProfile = profileStore.getActiveProfile()
	return if activeProfile then activeProfile.isPreset else true
end

type Props = {
	LayoutOrder: number?,
}

local function ProfileSelection(props: Props)
	local nextOrder = createNextOrder()

	local profileStore = ProfileStore.get()
	local activeProfileId = useSignalState(profileStore.getActiveProfileId)
	local currentPlaceKey = useSignalState(profileStore.getCurrentPlaceKey)
	local items = useSignalState(profileDropdownItems)
	local isPinned = useSignalState(profileStore.getIsCurrentPlacePinned)
	local isPreset = useSignalState(isPresetProfile)

	local editBtn = e(Button, {
		text = "Edit",
		icon = IconName.Pencil,
		size = InputSize.Small,
		variant = ButtonVariant.Standard,
		isDisabled = isPreset,
		onActivated = function()
			ModalStore.get().open("customProfile", {
				props = {
					existingProfileId = activeProfileId,
				},
			})
		end,
		-- just have to hard code this because we create the element early
		LayoutOrder = 100,
	})

	return e(Section, {
		title = "Profile",
		hasDivider = true,
		canToggleExpand = false,
		LayoutOrder = props.LayoutOrder,
	}, {
		LayoutBlock = e(View, {
			tag = "size-full-0 auto-y row gap-small align-y-center",
			LayoutOrder = nextOrder(),
		}, {
			-- We have to wrap the dropdown in a flex grow container because
			-- dropdown doesn't expose any fill behavior prop :(
			DropdownContainer = e(View, {
				tag = "auto-y grow",
				LayoutOrder = nextOrder(),
			}, {
				ProfileSelector = e(Dropdown.Root, {
					label = "",
					value = activeProfileId,
					items = items,
					size = InputSize.Small,
					width = UDim.new(1, 0),
					onItemChanged = function(id)
						if id == CUSTOM_PROFILE_TRIGGER_ID then
							ModalStore.get().open("customProfile")
							return
						end

						if type(id) == "string" then
							profileStore.setActiveProfile(id)
							Telemetry.fireEvent({
								type = "profileSelected",
								value = Types.ProfileSelected.new({ profile = id }),
							})
						end
					end,
					LayoutOrder = nextOrder(),
				}),
			}),

			PinBtn = e(Tooltip, {
				title = if isPinned then "Unpin profile from this game" else "Pin profile to this game",
				align = PopoverAlign.End,
				side = PopoverSide.Top,
				LayoutOrder = nextOrder(),
			}, {
				PinBtn = e(IconButton, {
					icon = {
						name = IconName.Pin,
						variant = if isPinned then IconVariant.Filled else IconVariant.Regular,
					},
					size = InputSize.Small,
					variant = ButtonVariant.Standard,
					isDisabled = currentPlaceKey == nil,
					onActivated = function()
						profileStore.toggleCurrentPlacePin()
					end,
				}),
			}),

			EditBtn = if isPreset
				then e(Tooltip, {
					title = "Built-in profiles can't be edited",
					align = PopoverAlign.End,
					side = PopoverSide.Top,
					LayoutOrder = nextOrder(),
				}, {
					EditBtn = editBtn,
				})
				else editBtn,
		}),
	})
end

return ProfileSelection
