local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactFlow = require(Packages.ReactFlow)

local Snackbar = Foundation.Snackbar
local IconName = Foundation.Enums.IconName

local useTween = ReactFlow.useTween

local e = React.createElement
local useCallback = React.useCallback
local useEffect = React.useEffect

export type NotificationType = "info" | "error"

type Props = {
	type: NotificationType,
	text: string,
	onClose: () -> (),
	LayoutOrder: number?,
}

local function Notification(props: Props)
	local info = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local alpha: any, updateAlpha = useTween({
		start = 0,
		info = info,
	})

	local onClose = useCallback(function()
		updateAlpha({
			target = 0,
			info = info,
		})

		-- Wait for the animation to complete, then tell the container to close
		task.delay(0.1, props.onClose)
	end, { updateAlpha })

	-- Animate on entry
	useEffect(function()
		updateAlpha({
			target = 1,
			info = info,
		})

		local thread = task.delay(4, onClose)
		return function()
			task.cancel(thread)
		end
	end, { updateAlpha :: any, info, onClose })

	return e(Snackbar, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = alpha:map(function(t: number)
			local offscreenAmount = 46
			local onscreenOffset = 8

			return UDim2.new(0.5, 0, 1, math.lerp(offscreenAmount, -onscreenOffset, t))
		end),
		title = props.text,
		icon = if props.type == "info" then IconName.CircleI else IconName.TriangleExclamation,
		onClose = onClose,
	})
end

return Notification
