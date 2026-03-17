--[[
	Formats an elapsed time in seconds into a human-readable string.

	The format varies based on duration:
	- Under 1 hour: "MM:SS" (e.g., "5:03", "45:59")
	- 1 hour or more: "H:MM:SS" (e.g., "1:05:03", "12:45:59")

	Seconds and minutes (when hours are present) are always zero-padded to 2 digits.
]]

local function formatElapsedTime(elapsedSeconds: number): string
	local hours = math.floor(elapsedSeconds / 3600)
	local minutes = math.floor((elapsedSeconds % 3600) / 60)
	local seconds = elapsedSeconds % 60

	local paddedSeconds = string.format("%02d", seconds)

	if hours > 0 then
		local paddedMinutes = string.format("%02d", minutes)
		return `{hours}:{paddedMinutes}:{paddedSeconds}`
	else
		return `{minutes}:{paddedSeconds}`
	end
end

return formatElapsedTime
