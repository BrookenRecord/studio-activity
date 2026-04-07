local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local ProfileStore = require(Plugin.Source.PresenceManager.ProfileStore)
local Section = require(script.Parent.Section)
local Telemetry = require(Plugin.Source.Telemetry.fireEventAsync)
local Types = require(Plugin.Source.Telemetry.Types)

local View = Foundation.View
local Dropdown = Foundation.Dropdown
local Button = Foundation.Button
local Tooltip = Foundation.Tooltip
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName
local PopoverSide = Foundation.Enums.PopoverSide
local PopoverAlign = Foundation.Enums.PopoverAlign

type IconName = Foundation.IconName

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

local profileDropdownItems = Charm.computed(function(): Foundation.DropdownItems
	type Record = { id: string, name: string, icon: IconName }
	local presetProfiles: { Record } = {}
	local customProfiles: { Record } = {}

	local allProfiles = ProfileStore.get().getAllProfiles()
	for id, profile in allProfiles do
		local target: { Record } = if profile.isPreset then presetProfiles else customProfiles
		table.insert(target, {
			id = id,
			icon = profile.icon,
			name = profile.name,
		})
	end

	-- Sort the list of profiles
	table.sort(presetProfiles, function(a, b)
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

	return items
end)

type Props = {
	LayoutOrder: number?,
}

local function ProfileSelection(props: Props)
	local nextOrder = createNextOrder()

	local profileStore = ProfileStore.get()
	local activeProfileId = useSignalState(profileStore.getActiveProfileId)

	local items = useSignalState(profileDropdownItems)

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

			Tooltip = e(Tooltip, {
				title = "Custom profiles are coming soon!",
				align = PopoverAlign.Center,
				side = PopoverSide.Left,
				LayoutOrder = nextOrder(),
			}, {
				EditBtn = e(Button, {
					text = "Edit",
					icon = IconName.Pencil,
					size = InputSize.Small,
					isDisabled = true,
					onActivated = function() end,
					LayoutOrder = nextOrder(),
				}),
			}),
		}),
	})
end

return ProfileSelection
