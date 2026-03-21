local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)

local useTokens = Foundation.Hooks.useTokens

type Status = {
	statusLabel: string,
	statusLabelColor: Foundation.ColorStyle,
	statusBadgeColor: Foundation.ColorStyle,
}

local function useAccountStatus(isActive: boolean): Status
	local tokens = useTokens()

	if isActive then
		return {
			statusLabel = "Sending presence",
			statusLabelColor = tokens.Color.Content.Muted,
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

return useAccountStatus
