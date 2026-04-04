local createPluginStore = require(script.createPluginStore)

local instance = nil

local function get()
	if not instance then
		instance = createPluginStore()
	end
	return instance
end

return { get = get }
