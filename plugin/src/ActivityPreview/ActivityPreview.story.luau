local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local Storyteller = require(Packages.Storyteller)

local ActivityPreview = require(script.Parent.ActivityPreview)

local View = Foundation.View

local e = React.createElement

local story: Storyteller.Story<any> = {
	summary = "ActivityPreview gives a visual preview of a Discord Rich Presence (Activity) widget.",
	story = function()
		return e(View, {
			tag = "anchor-center-center position-center-center row align-x-center align-y-center",
			Size = UDim2.new(0, 260, 1, 0),
		}, {
			Story = e(ActivityPreview, {
				activity = {
					name = "Roblox Studio 1",
					details = "Roblox Studio 2",
					state = "Roblox Studio 3",
					assets = {
						largeImage = "",
						largeText = "Editing in Roblox Studio",

						smallImage = "",
						smallText = "Lorem Ipsum",
					},
				},
			}),
		})
	end,
}

return story
