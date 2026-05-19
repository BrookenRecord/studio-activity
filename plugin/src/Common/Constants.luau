local Constants = {}

local REDIRECT_BASE =
	"https://activity.brooke.sh/?utm_source=discord&utm_medium=rich_presence&utm_campaign=studio_activity"
Constants.PLUGIN_LINK_PROFILE_LINK = `{REDIRECT_BASE}&utm_content=profile_link`
Constants.PLUGIN_LINK_PROFILE_BUTTON = `{REDIRECT_BASE}&utm_content=profile_button`

return table.freeze(Constants)
