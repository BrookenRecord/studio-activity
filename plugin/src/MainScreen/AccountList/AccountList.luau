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

local STATUS_ORDER = { ready = 1, error = 2, loading = 3 }

local userChildrenComputed = Charm.computed(function()
	local accountStore = AccountStore.get()
	local users = accountStore.cachedUsers()

	local sortedEntries = {}
	for id, user in users do
		table.insert(sortedEntries, { id = id, user = user })
	end

	table.sort(sortedEntries, function(a, b)
		local aOrder = STATUS_ORDER[a.user.status] or 4
		local bOrder = STATUS_ORDER[b.user.status] or 4
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		if a.user.status == "ready" and b.user.status == "ready" then
			return (a.user.details.globalName or "") < (b.user.details.globalName or "")
		end
		return a.id < b.id
	end)

	local children: { React.ReactNode } = {}
	for index, entry in sortedEntries do
		table.insert(
			children,
			e(AccountEntry, {
				key = entry.id,
				accountId = entry.id,
				localUser = entry.user,
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
