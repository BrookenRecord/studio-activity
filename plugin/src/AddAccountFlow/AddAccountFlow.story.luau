local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local React = require(Packages.React)
local Storyteller = require(Packages.Storyteller)

local AddAccountFlow = require(script.Parent.AddAccountFlow)

local e = React.createElement

local story: Storyteller.Story<any> = {
	story = function()
		return e(AddAccountFlow, {})
	end,
}

return story
