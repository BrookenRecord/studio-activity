local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AuthContext = require(script.Parent.Parent.AuthContext)

local TextInput = Foundation.TextInput
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName

local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useCallback = React.useCallback

type Props = {
	LayoutOrder: number?,
}

local function BrowserFlow(_props: Props)
	local auth = AuthContext.useAuth()

	local status = useSignalState(auth.browserCodeFlow.status)
	local sessionInfo = useSignalState(auth.browserCodeFlow.sessionInfo)
	local errorText = useSignalState(auth.browserCodeFlow.error)

	local textbox, setTextbox = useState<<TextBox?>>(nil)

	local selectAll = useCallback(function()
		if textbox then
			local len = #textbox.Text
			if len == 0 then
				return
			end

			if not textbox:IsFocused() then
				textbox:CaptureFocus()
			end

			textbox.SelectionStart = 1
			textbox.CursorPosition = len + 1
		end
	end, { textbox })

	useEffect(function()
		if textbox then
			textbox.TextEditable = false

			local focusConnection = textbox.Focused:Connect(selectAll)

			-- Re-select all if the user clicks to move the cursor while focused.
			-- CursorPosition changes when the user clicks within the box or
			-- arrow-keys around, so we catch that and snap the selection back.
			local cursorChangedConnection = textbox:GetPropertyChangedSignal("CursorPosition"):Connect(function()
				-- CursorPosition is -1 when the box isn't focused
				if textbox.CursorPosition == -1 then
					return
				end

				selectAll()
			end)

			return function()
				focusConnection:Disconnect()
				cursorChangedConnection:Disconnect()
			end :: any
		end

		return nil
	end, { textbox :: any, selectAll })

	-- Show whichever message best reflects the current state.
	local hint: string
	if status == "requesting" then
		hint = "Generating link…"
	elseif status == "exchanging" then
		hint = "Linking your account…"
	elseif status == "authorized" then
		hint = "Account linked. You're all set."
	elseif status == "denied" then
		hint = "You cancelled the request in Discord."
	elseif status == "expired" then
		hint = "This link expired. Try again."
	elseif status == "error" then
		hint = `Something went wrong: {errorText or "unknown error"}`
	else
		hint = "Paste into your browser to authorize. Return here when done."
	end

	local startUrl = if sessionInfo then sessionInfo.startUrl else ""

	return e(TextInput, {
		onReturnPressed = function() end,
		text = startUrl,
		label = "Continue in browser",
		hint = hint,
		width = UDim.new(1, 0),
		size = InputSize.Medium,
		ref = function(rbx: Frame?)
			if rbx then
				setTextbox(rbx:FindFirstChildWhichIsA("TextBox", true))
			end
		end,
		iconTrailing = {
			name = IconName.TwoStackedSquares,
			onActivated = selectAll,
		},
		onChanged = function() end,
	})
end

return BrowserFlow
