local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local useEffect = React.useEffect

export type Props = {
	dockWidget: DockWidgetPluginGui,
	title: string?,
	enabled: boolean?,
	zIndexBehavior: Enum.ZIndexBehavior?,
	onClose: () -> ()?,
	onWidgetRestored: (boolean) -> ()?,
	onEnabledChanged: (boolean) -> ()?,
	onSizeChange: (size: Vector2) -> ()?,
	children: React.ReactNode,
}

local function PluginWidget(props: Props)
	local dockWidget = props.dockWidget
	local title = props.title
	local enabled = if props.enabled == nil then true else props.enabled
	local zIndexBehavior = props.zIndexBehavior or Enum.ZIndexBehavior.Sibling
	local onClose = props.onClose
	local onWidgetRestored = props.onWidgetRestored
	local onEnabledChanged = props.onEnabledChanged
	local onSizeChange = props.onSizeChange

	useEffect(function(): (() -> ())?
		if onClose then
			dockWidget:BindToClose(onClose)
			return function()
				dockWidget:BindToClose()
			end
		end
		return
	end, { dockWidget or false, onClose or false } :: { any })

	useEffect(function()
		if title and dockWidget.Title ~= title then
			dockWidget.Title = title
			dockWidget.Name = title
		end
	end, { dockWidget or false, title } :: { any })

	useEffect(function()
		if dockWidget.Enabled ~= enabled then
			dockWidget.Enabled = enabled
		end
	end, { dockWidget or false, enabled } :: { any })

	useEffect(function()
		if dockWidget.ZIndexBehavior ~= zIndexBehavior then
			dockWidget.ZIndexBehavior = zIndexBehavior
		end
	end, { dockWidget or false, zIndexBehavior } :: { any })

	useEffect(function(): (() -> ())?
		if onSizeChange ~= nil then
			local connection = dockWidget:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				onSizeChange(dockWidget.AbsoluteSize)
			end)
			return function()
				connection:Disconnect()
			end
		end
		return
	end, { dockWidget or false, onSizeChange or false } :: { any })

	useEffect(function(): (() -> ())?
		if onWidgetRestored and dockWidget.HostWidgetWasRestored then
			onWidgetRestored(dockWidget.Enabled)
		end
		return
	end, { dockWidget })

	useEffect(function(): (() -> ())?
		if onEnabledChanged then
			local connection = dockWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
				onEnabledChanged(dockWidget.Enabled)
			end)
			return function()
				connection:Disconnect()
			end
		end
		return
	end, { dockWidget :: any, onEnabledChanged or false })

	return if dockWidget then ReactRoblox.createPortal(props.children, dockWidget) else nil
end

return PluginWidget
