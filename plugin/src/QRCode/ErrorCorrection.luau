export type Level = "Low" | "Medium" | "Quartile" | "High"

local NUMERIC_LEVEL: { [Level]: number } = {
	Low = 1,
	Medium = 2,
	Quartile = 3,
	High = 4,
}

local function toNumber(level: Level): number
	return NUMERIC_LEVEL[level]
end

return {
	Low = "Low" :: "Low",
	Medium = "Medium" :: "Medium",
	Quartile = "Quartile" :: "Quartile",
	High = "High" :: "High",
	toNumber = toNumber,
}
