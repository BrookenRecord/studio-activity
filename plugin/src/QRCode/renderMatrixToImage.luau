--[[
	Writes a QR code matrix as pixel data onto an EditableImage.
	Foreground modules are drawn with the given color and alpha.
	Background modules are fully transparent.
]]
local function renderMatrixToImage(
	image: EditableImage,
	imageSize: number,
	matrix: { [number]: { [number]: number } },
	color: Color3,
	alpha: number
)
	local matrixSize = #matrix
	local pixelBuffer = buffer.create(imageSize * imageSize * 4)

	local cr = math.round(color.R * 255)
	local cg = math.round(color.G * 255)
	local cb = math.round(color.B * 255)
	local ca = math.round(alpha * 255)

	local offset = 0
	for row = 0, imageSize - 1 do
		local matrixRow = matrix[math.floor(row / imageSize * matrixSize) + 1]
		for col = 0, imageSize - 1 do
			local matrixCol = math.floor(col / imageSize * matrixSize) + 1
			if matrixRow[matrixCol] > 0 then
				buffer.writeu8(pixelBuffer, offset, cr)
				buffer.writeu8(pixelBuffer, offset + 1, cg)
				buffer.writeu8(pixelBuffer, offset + 2, cb)
				buffer.writeu8(pixelBuffer, offset + 3, ca)
			else
				buffer.writeu8(pixelBuffer, offset, 255)
				buffer.writeu8(pixelBuffer, offset + 1, 255)
				buffer.writeu8(pixelBuffer, offset + 2, 255)
				buffer.writeu8(pixelBuffer, offset + 3, 0)
			end
			offset += 4
		end
	end

	image:WritePixelsBuffer(Vector2.zero, Vector2.new(imageSize, imageSize), pixelBuffer)
end

return renderMatrixToImage
