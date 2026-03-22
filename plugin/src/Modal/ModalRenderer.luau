local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AddAccountFlow = require(Plugin.Source.AddAccountFlow)
local LocalStorageStore = require(Plugin.Source.Plugin.LocalStorageStore)
local ModalStore = require(script.Parent.ModalStore)
local TelemetryOptOutDialog = require(Plugin.Source.Telemetry.TelemetryOptOutDialog)

local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useEffect = React.useEffect

type ModalConfig = {
	type: "sheet" | "dialog",
	render: (isOpen: boolean, onClose: (result: any?) -> (), props: { [string]: any }?) -> React.ReactNode,
}

local MODAL_REGISTRY: { [string]: ModalConfig } = {
	addAccount = {
		type = "sheet",
		render = function(isOpen, onClose, _props)
			return e(AddAccountFlow, {
				isOpen = isOpen,
				onClose = onClose,
			})
		end,
	},

	telemetryOptOut = {
		type = "dialog",
		render = function(_isOpen, onClose, _props)
			return e(TelemetryOptOutDialog, {
				onClose = onClose,
			})
		end,
	},
}

local function ModalRenderer()
	local modalStore = useSignalState(ModalStore.get)
	local activeModal = useSignalState(modalStore.getActiveModal)
	local activeProps = useSignalState(modalStore.getActiveProps)

	-- Auto-open: telemetry opt-out dialog on first launch
	local localStorageStore = useSignalState(LocalStorageStore.get)
	local localStorage = useSignalState(localStorageStore.getStorage)
	local isLocalStorageLoading = useSignalState(localStorageStore.getIsLoading)

	useEffect(function()
		if not isLocalStorageLoading and not localStorage.wasUserPromptedForTelemetry then
			modalStore.open("telemetryOptOut", { priority = 10 })
		end
	end, { isLocalStorageLoading, localStorage.wasUserPromptedForTelemetry, modalStore.open })

	local children: { [string]: React.ReactNode } = {}

	for id, config in MODAL_REGISTRY do
		local isOpen = (activeModal == id)

		if config.type == "sheet" then
			-- Sheet modals are always mounted; isOpen toggles visibility
			local function onClose(result: any?)
				modalStore.close(id, result)
			end

			children[id] = config.render(isOpen, onClose, if isOpen then activeProps else nil)
		elseif config.type == "dialog" then
			-- Dialog modals are only mounted when active
			if isOpen then
				local function onClose(result: any?)
					modalStore.close(id, result)
				end

				children[id] = config.render(isOpen, onClose, activeProps)
			end
		end
	end

	return e(React.Fragment, nil, children)
end

return ModalRenderer
