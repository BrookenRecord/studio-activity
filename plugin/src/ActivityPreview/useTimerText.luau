local Plugin = script:FindFirstAncestor("StudioActivity")

local Common = Plugin.Source.Common
local Packages = Plugin.Packages

local React = require(Packages.React)
local formatElapsedTime = require(Common.formatElapsedTime)

local useBinding = React.useBinding
local useEffect = React.useEffect

local function useTimerText(startTime: number): React.Binding<string>
	local timerText, setTimerText = useBinding(formatElapsedTime(0))

	-- Every second, update the timer text with how much time has passed since
	-- the start time.
	useEffect(function()
		local isRunning = true

		local thread = task.spawn(function()
			while isRunning do
				local currentTime = os.time()
				local elapsedTime = currentTime - startTime

				setTimerText(formatElapsedTime(elapsedTime))
				task.wait(1)
			end
		end)

		return function()
			task.cancel(thread)
			isRunning = false
		end
	end, { startTime })

	return timerText
end

return useTimerText
