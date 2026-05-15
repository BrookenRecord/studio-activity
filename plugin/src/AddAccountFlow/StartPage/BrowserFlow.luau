local UserInputService = game:GetService("UserInputService")

local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactCharm = require(Packages.ReactCharm)

local AuthContext = require(script.Parent.Parent.AuthContext)
local NotificationStore = require(Plugin.Source.Notification.NotificationStore)
local Steps = require(script.Parent.Steps)

local TextInput = Foundation.TextInput
local InputSize = Foundation.Enums.InputSize

local useSignalState = ReactCharm.useSignalState

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useCallback = React.useCallback

local function sendCopyKeycode()
	local virtualInput: VirtualInput = UserInputService:CreateVirtualInput() :: any

	virtualInput:SendKey(true, Enum.KeyCode.LeftControl)
	virtualInput:SendKey(true, Enum.KeyCode.C)

	virtualInput:SendKey(false, Enum.KeyCode.LeftControl)
	virtualInput:SendKey(false, Enum.KeyCode.C)
end

local function BrowserFlow()
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

			local focusConnection = textbox.Focused:Connect(function()
				selectAll()

				sendCopyKeycode()
				NotificationStore.get().push("info", "Copied URL to clipboard")
			end)

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
	local hint: string?
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
		hint = nil
	end

	local startUrl = if sessionInfo then sessionInfo.startUrl else ""

	return e(Steps, {
		steps = {
			{
				id = "step-1",
				text = "Select to copy this link",
				content = e(TextInput, {
					onReturnPressed = function() end,
					text = startUrl,
					label = "",
					hint = hint,
					width = UDim.new(1, 0),
					size = InputSize.Small,
					ref = function(rbx: Frame?)
						if rbx then
							setTextbox(rbx:FindFirstChildWhichIsA("TextBox", true))
						end
					end,
					onChanged = function() end,
				}),
			},
			{
				id = "step-2",
				text = "Paste into your browser and authorize",
			},
			{
				id = "step-3",
				text = "Return here when done",
			},
		},
	})
end

return React.memo(BrowserFlow)
