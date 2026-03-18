local ErrorCorrection = require(script.ErrorCorrection)
local QRCodeDisplay = require(script.QRCodeDisplay)

export type ErrorCorrectionLevel = ErrorCorrection.Level
export type QRCodeDisplayProps = QRCodeDisplay.Props

return {
	QRCodeDisplay = QRCodeDisplay,
	ErrorCorrection = ErrorCorrection,
}
