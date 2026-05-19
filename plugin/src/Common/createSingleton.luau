local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

--[[
	Returns a lazy getter for a singleton store. The factory is invoked on
	first call and the result is cached forever. The factory runs inside
	`Charm.untracked`, so any signal reads or writes performed during the
	store's own initialization do NOT register as dependencies of whichever
	reactive context (effect / computed / React render) happened to make the
	first call. The returned store is still fully reactive at the method
	level — its internal signals and computeds keep working as normal.

	Without this, a factory that synchronously reads and writes one of its
	own internal signals during init (e.g. `createPlaceDetailsStore` calling
	`prefetchPlaceIds(game.PlaceId)`) would link that signal as a dependency
	of the calling reactive context, and every subsequent mutation of the
	signal would cause the caller to re-evaluate — constructing a brand new
	store and feeding back into the same cycle.
]]
local function createSingleton<T>(factory: () -> T): () -> T
	local instance: T? = nil
	local initializing = false

	return function(): T
		if instance ~= nil then
			return instance :: T
		end
		if initializing then
			error("createSingleton: recursive factory invocation detected", 2)
		end
		initializing = true
		local ok, result = pcall(Charm.untracked, factory)
		initializing = false
		if not ok then
			error(result, 2)
		end
		instance = result
		return instance :: T
	end
end

return createSingleton
