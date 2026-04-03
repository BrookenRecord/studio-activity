--[[
	The purpose of this module is to prevent the plugin loading heavy libraries
	(COUGH react) until the user actually interacts with it.
]]

local StudioService = game:GetService("StudioService")

--[[
	Creates a signal that buffers events fired before any listener connects.
	On first connect, all buffered events are flushed to that listener.
	Calling clearBuffer() discards pending events without delivering them.
]]
local function createBufferedSignal()
	local listeners: { (...any) -> () } = {}
	local buffer: { { [number]: any, n: number } }? = {}

	local function fire(...: any)
		if #listeners > 0 then
			for _, listener in listeners do
				task.spawn(listener, ...)
			end
		elseif buffer then
			table.insert(buffer, table.pack(...))
		end
	end

	local function connect(callback: (...any) -> ()): { Disconnect: () -> () }
		table.insert(listeners, callback)

		if buffer then
			local pending = buffer
			buffer = nil
			for _, args in pending do
				task.spawn(callback, table.unpack(args, 1, args.n))
			end
		end

		return {
			Disconnect = function()
				local index = table.find(listeners, callback)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
	end

	local function clearBuffer()
		buffer = nil
	end

	local function destroy()
		listeners = {}
		buffer = nil
	end

	return {
		Fire = fire,
		Connect = connect,
		ClearBuffer = clearBuffer,
		Destroy = destroy,
	}
end

export type BufferedSignal = typeof(createBufferedSignal())

export type GetLocalizedTextFunc = ((string, string) -> string) -> string

export type ButtonInfo = {
	getName: GetLocalizedTextFunc,
	getDescription: GetLocalizedTextFunc,
	icon: string?,
	text: (string | GetLocalizedTextFunc)?,
	clickableWhenViewportHidden: boolean?,
	enabled: boolean?,
}

export type DockWidgetInfo = {
	dockWidgetPluginGuiInfo: DockWidgetPluginGuiInfo,
	getDockTitle: GetLocalizedTextFunc,
	id: string,
	name: (string | GetLocalizedTextFunc)?,
	zIndexBehavior: Enum.ZIndexBehavior?,
}

export type Args = {
	plugin: Plugin,
	pluginName: string,
	translationResourceTable: LocalizationTable,
	overrideLocaleId: string?,
	getToolbarName: GetLocalizedTextFunc?,
	buttonInfo: ButtonInfo?,
	dockWidgetInfo: DockWidgetInfo?,
	shouldImmediatelyOpen: (() -> boolean)?,
}

export type PluginLoaderContext = {
	plugin: Plugin,
	toolbar: PluginToolbar?,
	mainButton: PluginToolbarButton?,
	mainDockWidget: DockWidgetPluginGui?,
	mainButtonClickedSignal: BufferedSignal,
	waitForUserInteraction: () -> boolean,
}

local function getLocale(overrideLocaleId: string?): string
	if overrideLocaleId then
		return overrideLocaleId
	end
	return StudioService["StudioLocaleId"]
end

local function createLocalizer(
	translationResourceTable: LocalizationTable,
	overrideLocaleId: string?
): (string, string) -> string
	local locale = getLocale(overrideLocaleId)
	local translator = translationResourceTable:GetTranslator(locale)

	return function(scope: string, key: string): string
		local stringKey = `{scope}.{key}`
		local success, result = pcall(translator.FormatByKey, translator, stringKey)
		if success then
			return result
		end
		return stringKey
	end
end

local function createPluginLoader(args: Args): PluginLoaderContext
	local pluginInstance = args.plugin
	local connections: { RBXScriptConnection } = {}
	local signals: { BufferedSignal } = {}
	local destroyed = false
	local userHasInteracted = false
	local interactionEvent = Instance.new("BindableEvent")

	local localize = createLocalizer(args.translationResourceTable, args.overrideLocaleId)

	local function onUserInteracted()
		if userHasInteracted then
			return
		end
		userHasInteracted = true
		interactionEvent:Fire()
	end

	-- Create toolbar and button
	local toolbar: PluginToolbar? = nil
	local mainButton: PluginToolbarButton? = nil
	local mainButtonClickedSignal = createBufferedSignal()
	table.insert(signals, mainButtonClickedSignal)

	if args.buttonInfo then
		local buttonInfo = args.buttonInfo

		local toolbarName = if args.getToolbarName then args.getToolbarName(localize) else args.pluginName
		toolbar = pluginInstance:CreateToolbar(toolbarName)

		mainButton = (toolbar :: PluginToolbar):CreateButton(
			buttonInfo.getName(localize),
			buttonInfo.getDescription(localize),
			buttonInfo.icon or "",
			if type(buttonInfo.text) == "function"
				then (buttonInfo.text :: GetLocalizedTextFunc)(localize)
				else buttonInfo.text
		)

		if buttonInfo.clickableWhenViewportHidden then
			(mainButton :: PluginToolbarButton).ClickableWhenViewportHidden = true
		end
		if buttonInfo.enabled ~= nil then
			(mainButton :: PluginToolbarButton).Enabled = buttonInfo.enabled :: boolean
		end

		local buttonConnection = (mainButton :: PluginToolbarButton).Click:Connect(function()
			onUserInteracted()
			mainButtonClickedSignal.Fire()
		end)
		table.insert(connections, buttonConnection)
	end

	-- Create dock widget
	local mainDockWidget: DockWidgetPluginGui? = nil

	if args.dockWidgetInfo then
		local dockInfo = args.dockWidgetInfo
		local dockTitle = dockInfo.getDockTitle(localize)

		mainDockWidget = pluginInstance:CreateDockWidgetPluginGuiAsync(dockInfo.id, dockInfo.dockWidgetPluginGuiInfo)

		local widget = mainDockWidget :: DockWidgetPluginGui
		widget.Title = dockTitle
		widget.ZIndexBehavior = dockInfo.zIndexBehavior or Enum.ZIndexBehavior.Sibling

		if dockInfo.name then
			widget.Name = if type(dockInfo.name) == "function"
				then (dockInfo.name :: GetLocalizedTextFunc)(localize)
				else dockInfo.name :: string
		end

		local widgetConnection = widget:GetPropertyChangedSignal("Enabled"):Connect(function()
			if widget.Enabled then
				onUserInteracted()
			end
			if mainButton then
				(mainButton :: PluginToolbarButton):SetActive(widget.Enabled)
			end
		end)
		table.insert(connections, widgetConnection)

		if widget.Enabled then
			onUserInteracted()
		end
		if mainButton then
			(mainButton :: PluginToolbarButton):SetActive(widget.Enabled)
		end
	end

	if args.shouldImmediatelyOpen and args.shouldImmediatelyOpen() then
		onUserInteracted()
	end

	local function waitForUserInteraction(): boolean
		if not userHasInteracted then
			interactionEvent.Event:Wait()
		end

		-- Discard any events buffered during the wait so that the initial
		-- interaction (e.g. the button click that opened the plugin) does not
		-- replay when the app later connects its listeners.
		mainButtonClickedSignal.ClearBuffer()

		return not destroyed
	end

	pluginInstance.Unloading:Connect(function()
		destroyed = true

		-- Resume any threads blocked in waitForUserInteraction
		interactionEvent:Fire()

		for _, connection in connections do
			connection:Disconnect()
		end
		for _, signal in signals do
			signal.Destroy()
		end

		interactionEvent:Destroy()
	end)

	return {
		plugin = pluginInstance,
		toolbar = toolbar,
		mainButton = mainButton,
		mainDockWidget = mainDockWidget,
		mainButtonClickedSignal = mainButtonClickedSignal,
		waitForUserInteraction = waitForUserInteraction,
	}
end

return createPluginLoader
