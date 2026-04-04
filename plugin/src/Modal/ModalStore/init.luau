local createModalStore = require(script.createModalStore)
export type ModalId = createModalStore.ModalId

local instance = nil

local function get()
	if not instance then
		instance = createModalStore()
	end
	return instance
end

return { get = get }
