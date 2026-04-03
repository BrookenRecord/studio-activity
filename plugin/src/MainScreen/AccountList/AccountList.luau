local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AccountEntry = require(script.Parent.AccountEntry)
local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local LinkAccountEntry = require(script.Parent.LinkAccountEntry)
local NoneLinkedBlock = require(script.Parent.NoneLinkedBlock)
local Section = require(script.Parent.Parent.Section)

local useSignalState = ReactCharm.useSignalState

local e = React.createElement

local STATUS_ORDER = { ready = 1, error = 2, loading = 3 }

local userChildrenComputed = Charm.computed(function(): React.ReactNode
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

	if #children == 0 then
		return {
			e(NoneLinkedBlock, {
				key = "NoneLinkedBlock",
				LayoutOrder = 1,
			}),
		}
	end

	if #children < 3 then
		table.insert(
			children,
			e(LinkAccountEntry, {
				key = "LinkAccount",
				LayoutOrder = 3,
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

return React.memo(AccountList)
