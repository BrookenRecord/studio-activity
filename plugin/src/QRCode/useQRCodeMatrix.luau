local Plugin = script:FindFirstAncestor("StudioRichPresence")

local Packages = Plugin.Packages
local QRCode = require(Packages.QRCode)
local React = require(Packages.React)

local ErrorCorrection = require(script.Parent.ErrorCorrection)

export type Matrix = { [number]: { [number]: number } }

local function useQRCodeMatrix(text: string, level: ErrorCorrection.Level): Matrix
	return React.useMemo(function()
		local _, matrix = (QRCode :: any).qrcode(text, ErrorCorrection.toNumber(level))
		return matrix
	end, { text, level })
end

return useQRCodeMatrix
