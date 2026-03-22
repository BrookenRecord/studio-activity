local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)

local useState = React.useState
local useEffect = React.useEffect

local function useRefProperty<T>(ref: { current: any? }, propName: string, fallbackValue: T): T
	local propValue, setPropValue = useState(fallbackValue)

	useEffect(function()
		if not ref.current then
			setPropValue(fallbackValue)
			return
		end

		setPropValue((ref.current :: any)[propName])
		local connection = ref.current:GetPropertyChangedSignal(propName):Connect(function()
			setPropValue((ref.current :: any)[propName])
		end)

		return function()
			connection:Disconnect()
		end
	end, { ref.current, propName, fallbackValue } :: { any })

	return propValue
end

return useRefProperty
