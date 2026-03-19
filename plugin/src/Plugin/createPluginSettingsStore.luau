local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Charm = require(Packages.Charm)

-- local Logger = require(Plugin.Source.Logger)
local PluginStore = require(script.Parent.PluginStore)

export type PluginSettingsStore<T> = {
	getStorage: () -> T,
	setStorage: (T | (T) -> T) -> (),

	isSettingDefault: (settingName: string) -> boolean,

	getIsLoading: () -> boolean,
	getErr: () -> string?,

	dispose: () -> (),
}

--[[
	Creates a store to manage plugin settings.

	Settings are persisted using Plugin:SetSetting and Plugin:GetSetting, and
    are stored as JSON strings. The settings are loaded once when the store is
    first created, and any changes to the settings are automatically saved.
]]
local function createPluginSettingsStore<T>(
	storageKey: string,
	defaultValue: T,
	validate: (value: any) -> (boolean, string)
): PluginSettingsStore<T>
	local getStorage, setStorage = Charm.signal(defaultValue)
	local getIsLoading, setIsLoading = Charm.signal(true)
	local getErr, setErr = Charm.signal(nil :: string?)

	local function readPluginSettingsAsync(plugin: Plugin): T?
		-- Logger:Info(`reading plugin settings for {storageKey} from disk...`)

		local data = plugin:GetSetting(storageKey)

		-- Logger:Debug(`read raw plugin settings for {storageKey}:`, data)

		if typeof(data) == "string" then
			-- Logger:Info(`deserializing plugin settings for {storageKey} to object...`)

			local success, result = pcall(function()
				return HttpService:JSONDecode(data)
			end)

			if not success then
				-- Logger:Warn(`failed to load plugin settings for {storageKey}:`, result)
				setErr(result)
				return nil
			end

			local isValid, message = validate(result)

			if not isValid then
				-- Logger:Warn(`plugin settings are malformed for {storageKey}:`, message)
				setErr(message)
				return nil
			end

			-- Logger:Info(`got plugin settings for {storageKey}:`, result)

			return result
		end

		-- Logger:Info("no plugin settings to read")

		return nil
	end

	local function writePluginSettingsAsync(plugin: Plugin, storage: T)
		-- Logger:Info("writing plugin settings to disk...")
		local data = HttpService:JSONEncode(storage)

		if data then
			local _success, _err = pcall(function()
				plugin:SetSetting(storageKey, data)
			end)

			-- if success then
			-- 	Logger:Info(`wrote plugin settings to disk: {data}`)
			-- else
			-- 	Logger:Warn(`failed to write plugin settings to disk: {err}`)
			-- end
		end
	end

	local prevStorage: T?
	local dispose = Charm.effect(function()
		local storage = getStorage()
		local plugin = PluginStore.get().getPlugin()

		if plugin then
			if getIsLoading() then
				task.spawn(function()
					local data = readPluginSettingsAsync(plugin)
					if data then
						setStorage(data)
					end
					-- Logger:Debug("finished loading plugin settings")
					setIsLoading(false)
				end)
			end

			if storage ~= prevStorage then
				task.spawn(function()
					writePluginSettingsAsync(plugin, storage)
				end)
			end
		end

		prevStorage = storage
	end)

	local function isSettingDefault(settingName: string): boolean
		local storage = getStorage()
		if typeof(defaultValue) ~= "table" or typeof(storage) ~= "table" then
			return true
		end

		local settingDefaultValue = defaultValue[settingName]
		local storedValue = storage[settingName]

		return storedValue == nil or storedValue == settingDefaultValue
	end

	return {
		getIsLoading = getIsLoading,
		getErr = getErr,
		getStorage = getStorage,
		setStorage = setStorage,
		isSettingDefault = isSettingDefault,
		dispose = dispose,
	}
end

return createPluginSettingsStore
