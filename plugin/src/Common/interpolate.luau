--- Interpolates placeholders in a string with values from a dictionary.
---
--- Placeholders use `{key}` syntax, where `key` matches against alphanumeric
--- characters and underscores. Unmatched placeholders are left intact.
---
--- ```luau
--- interpolate("Hello {name}!", { name = "World" }) -- "Hello World!"
--- interpolate("{a} and {b}", { a = "yes" })        -- "yes and {b}"
--- ```
local function interpolate(input: string, vars: { [string]: string }): string
	return string.gsub(input, "{(%w+)}", function(key: string): string
		local value = vars[key]
		if value == nil then
			return "{" .. key .. "}"
		end
		return value
	end)
end

return interpolate
