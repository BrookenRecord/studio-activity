local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local useMemo = React.useMemo
local useState = React.useState
local useEffect = React.useEffect

export type ThemeName = "Dark" | "Light"

local MOCK_STUDIO = {
	ThemeChanged = Instance.new("BindableEvent").Event,
	Theme = {
		Name = "Light",
	},
}

local function useThemeName(): ThemeName
	local studio: Studio = useMemo(function()
		local success, result = pcall(function()
			return (settings() :: any).Studio
		end)

		return if success then result else MOCK_STUDIO
	end, {})

	local studioTheme, setStudioTheme = useState(studio.Theme.Name)

	local theme = useMemo(function(): ThemeName
		if studioTheme == "Dark" or studioTheme == "Light" then
			return studioTheme
		end
		return "Dark"
	end, { studioTheme })

	useEffect(function(): any
		local connection = studio.ThemeChanged:Connect(function()
			setStudioTheme(studio.Theme.Name)
		end)

		return function()
			connection:Disconnect()
		end
	end, { studio })

	return theme :: ThemeName
end

return useThemeName
