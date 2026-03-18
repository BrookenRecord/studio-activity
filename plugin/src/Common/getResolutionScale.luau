local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local function getResolutionScale(): number
	-- This definitely won't work currently, but might work in the future
	local success, scale: number = pcall((GuiService :: any).GetResolutionScale, GuiService)

	if not success then
		if GuiService:IsTenFootInterface() then
			scale = 3
		else
			-- This is a horrible hack, but `GuiService::GetResolutionScale` is a
			-- privileged API. KeyCode images contain the resolution scale in the
			-- file name: `ButtonA@2x.png`.
			local ok, scaleHack = pcall(function()
				local buttonContentId = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonA)
				local buttonScale = buttonContentId:lower():match("@([%d%.]+)x%.%w+$")

				return tonumber(buttonScale or 1) or 1
			end)

			scale = if ok then scaleHack else 1
		end
	end

	return scale
end

return getResolutionScale
