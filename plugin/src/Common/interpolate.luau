--[[
	Interpolates placeholders in a string with values from a dictionary.

	Placeholders use `{key}` syntax, where `key` matches against alphanumeric
	characters and underscores. Unmatched placeholders are left intact so users
	see exactly what they typed when a key isn't recognised.

	Backslash escapes let users emit literal braces or backslashes:

	- `\{` and `\}` produce literal `{` and `}` (so the token isn't substituted)
	- `\\` produces a literal `\`
	- A trailing `\` at the end of input is treated as a literal `\`
	- `\` followed by any other character emits both characters verbatim

	```luau
	interpolate("Hello {name}!", { name = "World" }) -- "Hello World!"
	interpolate("{a} and {b}", { a = "yes" })        -- "yes and {b}"
	interpolate("\\{name\\}", { name = "ignored" })  -- "{name}"
	interpolate("path: C:\\\\dir", {})                -- "path: C:\\dir"
	```
]]
local function interpolate(input: string, vars: { [string]: string }): string
	local out: { string } = {}
	local i = 1
	local length = #input

	while i <= length do
		local char = string.sub(input, i, i)

		if char == "\\" then
			if i == length then
				table.insert(out, "\\")
				i += 1
			else
				table.insert(out, string.sub(input, i + 1, i + 1))
				i += 2
			end
		elseif char == "{" then
			local closeIndex = string.find(input, "}", i + 1, true)
			local key = if closeIndex then string.match(input, "^{([%w_]+)}", i) else nil

			if key and closeIndex then
				local value = vars[key]
				if value == nil then
					table.insert(out, "{" .. key .. "}")
				else
					table.insert(out, value)
				end
				i = (closeIndex :: number) + 1
			else
				table.insert(out, char)
				i += 1
			end
		else
			table.insert(out, char)
			i += 1
		end
	end

	return table.concat(out)
end

return interpolate
