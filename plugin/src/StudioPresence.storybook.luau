local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ContextProviders = require(Plugin.Source.Common.ContextProviders)
local MockPlugin = require(Plugin.Source.Testing.MockPlugin)

local View = Foundation.View

local e = React.createElement

return {
	name = "Studio Rich Presence",
	storyRoots = {
		script.Parent,
	},
	mapStory = function(Story)
		return function(props)
			return e(ContextProviders, {
				plugin = MockPlugin.new(),
				overlayGui = props.container,
				_TESTING_themeOverride = props.theme,
			}, {
				Container = e(View, {
					tag = "size-full row align-x-center align-y-center padding-xxlarge",
				}, {
					Story = e(Story, props),
				}),
			})
		end
	end,
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
