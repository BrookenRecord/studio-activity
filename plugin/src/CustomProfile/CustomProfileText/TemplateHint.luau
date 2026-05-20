local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local FeedbackAlert = Foundation.FeedbackAlert
local AlertSeverity = Foundation.Enums.AlertSeverity

local e = React.createElement

local TEMPLATES = {
	"placeName",
	"creator",
}

type Props = {
	LayoutOrder: number?,
}

local function TemplateHint(props: Props)
	local description =
		"Use the templating syntax to add dynamic data to your Discord activity. Available templates:\n\n"

	for i, template in TEMPLATES do
		description ..= `• \{{template}\}`
		if i ~= #TEMPLATES then
			description ..= "\n"
		end
	end

	description ..= "\n\nExample: I'm working on {placeName}"

	return e(FeedbackAlert, {
		severity = AlertSeverity.Info,
		title = "Templating Syntax",
		description = description,
		LayoutOrder = props.LayoutOrder,
	}, {})
end

return TemplateHint
