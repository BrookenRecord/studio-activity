local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AccountEntry = require(script.Parent.AccountEntry)
local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local Section = require(script.Parent.Parent.Section)

local useSignalState = ReactCharm.useSignalState

local e = React.createElement

local userChildrenComputed = Charm.computed(function()
	local accountStore = AccountStore.get()
	local users = accountStore.cachedUsers()

	-- Sort users alphabetically
	local sortedUsers = {}
	for _, user in users do
		if user.status ~= "ready" then
			-- TODO: Handle error and loading cases gracefully
			continue
		end

		table.insert(sortedUsers, user)
	end

	table.sort(sortedUsers, function(a, b)
		return a.details.globalName < b.details.globalName
	end)

	local children: { React.ReactNode } = {}
	for index, user in sortedUsers do
		table.insert(
			children,
			e(AccountEntry, {
				key = user.details.id,
				user = user.details,
				LayoutOrder = index,
			})
		)
	end

	return children
end)

type Props = {
	LayoutOrder: number?,
}

local function AccountList(props: Props)
	local userChildren = useSignalState(userChildrenComputed)

	return e(Section, {
		title = "Linked Accounts",
		hasDivider = true,
		LayoutOrder = props.LayoutOrder,
	}, userChildren)
end

return AccountList
