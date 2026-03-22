local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)

local createAccountStore = require(Plugin.Source.Authentication.AccountStore.createAccountStore)
type LocalUser = createAccountStore.LocalUser

local useTokens = Foundation.Hooks.useTokens

local PROBLEM_LABELS = {
	unauthorized = "Session expired",
	network = "Network error",
	unexpected = "Unexpected error",
}

type Status = {
	statusLabel: string,
	statusLabelColor: Foundation.ColorStyle,
	statusBadgeColor: Foundation.ColorStyle,
}

local function useAccountStatus(isActive: boolean, user: LocalUser): Status
	local tokens = useTokens()

	if user.status == "error" then
		local errorLabel = PROBLEM_LABELS[user.problemType] or user.problemType
		return {
			statusLabel = errorLabel,
			statusLabelColor = tokens.Color.Content.Muted,
			statusBadgeColor = tokens.Color.System.Alert,
		}
	else
		if isActive then
			return {
				statusLabel = "Sending presence",
				statusLabelColor = tokens.Color.Content.Default,
				statusBadgeColor = tokens.Color.System.Success,
			}
		else
			return {
				statusLabel = "Paused",
				statusLabelColor = tokens.Color.Content.Muted,
				statusBadgeColor = tokens.Color.Content.Muted,
			}
		end
	end
end

return useAccountStatus
