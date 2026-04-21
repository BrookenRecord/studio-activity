local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AddAccountFlow = require(Plugin.Source.AddAccountFlow)
local ConfirmationDialog = require(script.Parent.ConfirmationDialog)
local CustomProfile = require(Plugin.Source.CustomProfile)
local ModalStore = require(script.Parent.ModalStore)
local SettingsModal = require(Plugin.Source.UserSettings.SettingsModal)
local WelcomeDialog = require(Plugin.Source.Telemetry.TelemetryOptOutDialog)

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

	welcome = {
		type = "dialog",
		render = function(_isOpen, onClose, _props)
			return e(WelcomeDialog, {
				onClose = onClose,
			})
		end,
	},

	confirmation = {
		type = "dialog",
		render = function(_isOpen, onClose, props)
			return e(ConfirmationDialog, {
				title = props.title,
				body = props.body,
				onClose = onClose,
			})
		end,
	},

	settings = {
		type = "sheet",
		render = function(isOpen, onClose, _props)
			return e(SettingsModal, {
				isOpen = isOpen,
				onClose = onClose,
			})
		end,
	},

	customProfile = {
		type = "sheet",
		render = function(isOpen, onClose, props)
			return e(CustomProfile, {
				isOpen = isOpen,
				existingProfileId = props and props.existingProfileId,
				onClose = onClose,
			})
		end,
	},
}

local function ModalRenderer()
	local modalStore = ModalStore.get()
	local modalStack = useSignalState(modalStore.getModalStack)

	local entriesById: { [ModalStore.ModalId]: ModalStore.ModalStackEntry } = {}
	for _, entry in modalStack do
		entriesById[entry.id] = entry
	end

	local children: { React.ReactNode } = {}
	local function pushChild(key: string, node: React.ReactNode)
		table.insert(children, e(React.Fragment, { key = key }, node))
	end

	-- Keep closed sheets mounted so they preserve state.
	for id: ModalStore.ModalId, config in MODAL_REGISTRY do
		if config.type == "sheet" and entriesById[id] == nil then
			local function onClose(result: any?)
				modalStore.close(id, result)
			end

			pushChild(id, config.render(false, onClose, nil))
		end
	end

	-- Render open entries bottom-to-top so higher priority stacks above.
	for index = #modalStack, 1, -1 do
		local entry = modalStack[index]
		local config = MODAL_REGISTRY[entry.id]

		if config then
			local function onClose(result: any?)
				modalStore.close(entry.id, result)
			end

			pushChild(entry.id, config.render(true, onClose, entry.props))
		end
	end

	return e(React.Fragment, nil, children)
end

return ModalRenderer
