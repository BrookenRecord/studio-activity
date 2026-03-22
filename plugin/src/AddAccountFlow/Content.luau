local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)
local ReactUtils = require(Packages.ReactUtils)

local AuthContext = require(script.Parent.AuthContext)
local ConfirmationPage = require(script.Parent.ConfirmationPage.ConfirmationPage)
local StartPage = require(script.Parent.StartPage.StartPage)

local createNextOrder = ReactUtils.createNextOrder
local useSignalState = ReactCharm.useSignalState

local e = React.createElement

local function Content()
	local nextOrder = createNextOrder()
	local auth = AuthContext.useAuth()

	local status = useSignalState(auth.deviceCodeFlow.status)
	local showStartPage = status == "idle" or status == "requesting" or status == "polling"
	local showConfirmationPage = (not showStartPage) and status == "authorized"

	return e(React.Fragment, nil, {
		StartPage = showStartPage and e(StartPage, {
			LayoutOrder = nextOrder(),
		}),

		ConfirmationPage = showConfirmationPage and e(ConfirmationPage, {
			LayoutOrder = nextOrder(),
		}),
	})
end

return Content
