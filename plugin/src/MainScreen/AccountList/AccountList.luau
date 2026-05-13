local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AccountEntry = require(script.Parent.AccountEntry)
local AccountStore = require(Plugin.Source.Authentication.AccountStore)
local LinkAccountEntry = require(script.Parent.LinkAccountEntry)
local NoneLinkedBlock = require(script.Parent.NoneLinkedBlock)
local Section = require(Plugin.Source.Common.Section)

local createAccountStore = require(Plugin.Source.Authentication.AccountStore.createAccountStore)
type LocalUser = createAccountStore.LocalUser

local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useMemo = React.useMemo

local STATUS_ORDER = { ready = 1, error = 2, loading = 3 }

type SortedEntry = { id: string, user: LocalUser }

local sortedUsersComputed = Charm.computed(function(): { SortedEntry }
	local accountStore = AccountStore.get()
	local users = accountStore.cachedUsers()

	local entries: { SortedEntry } = {}
	for id, user in users do
		table.insert(entries, { id = id, user = user })
	end

	table.sort(entries, function(a, b)
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

	return entries
end)

type Props = {
	LayoutOrder: number?,
}

local function AccountList(props: Props)
	local sortedUsers = useSignalState(sortedUsersComputed)

	local children = useMemo(function(): { React.ReactNode }
		local result: { React.ReactNode } = {}

		for index, entry in sortedUsers do
			table.insert(
				result,
				e(AccountEntry, {
					key = entry.id,
					accountId = entry.id,
					localUser = entry.user,
					LayoutOrder = index,
				})
			)
		end

		if #result == 0 then
			return {
				e(NoneLinkedBlock, {
					key = "NoneLinkedBlock",
					LayoutOrder = 1,
				}),
			}
		end

		if #result < 3 then
			table.insert(
				result,
				e(LinkAccountEntry, {
					key = "LinkAccount",
					LayoutOrder = 3,
				})
			)
		end

		return result
	end, { sortedUsers })

	return e(Section, {
		title = "Linked Accounts",
		hasDivider = false,
		canToggleExpand = true,
		LayoutOrder = props.LayoutOrder,
	}, children)
end

return React.memo(AccountList)
