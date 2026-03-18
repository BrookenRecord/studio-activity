local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)

local TextInput = Foundation.TextInput
local InputSize = Foundation.Enums.InputSize
local IconName = Foundation.Enums.IconName

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useCallback = React.useCallback

type Props = {
	LayoutOrder: number?,
}

local function BrowserFlow(_props: Props)
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

	return e(TextInput, {
		onReturnPressed = function() end,
		text = "https://presence.brooke.sh/start/pjGXMs9OPcBh",
		label = "Continue in browser",
		hint = "Paste into your browser to authorize. Return here when done.",
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
