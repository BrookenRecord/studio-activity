local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AddAccountFlow = require(Plugin.Source.AddAccountFlow)
local ModalStore = require(script.Parent.ModalStore)
local TelemetryOptOutDialog = require(Plugin.Source.Telemetry.TelemetryOptOutDialog)

local useSignalState = ReactCharm.useSignalState

local e = React.createElement

type ModalConfig = {
	type: "sheet" | "dialog",
	render: (isOpen: boolean, onClose: (result: any?) -> (), props: { [string]: any }?) -> React.ReactNode,
}

local MODAL_REGISTRY: { [ModalStore.ModalId]: ModalConfig } = {
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
	local modalStore = ModalStore.get()
	local activeModal = useSignalState(modalStore.getActiveModal)
	local activeProps = useSignalState(modalStore.getActiveProps)

	local children: { [string]: React.ReactNode } = {}

	for id: ModalStore.ModalId, config in MODAL_REGISTRY do
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
