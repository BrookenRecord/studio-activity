local Plugin = script:FindFirstAncestor("StudioActivity")

local Common = Plugin.Source.Common
local Packages = Plugin.Packages
local JestGlobals = require(Packages.Dev.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local interpolate = require(Common.interpolate)

describe("interpolate", function()
	it("substitutes a single placeholder", function()
		expect(interpolate("Hello {name}!", { name = "World" })).toBe("Hello World!")
	end)

	it("substitutes multiple placeholders", function()
		expect(interpolate("{a} and {b}", { a = "one", b = "two" })).toBe("one and two")
	end)

	it("repeats the same placeholder", function()
		expect(interpolate("{x}-{x}", { x = "yes" })).toBe("yes-yes")
	end)

	it("preserves unknown placeholders verbatim", function()
		expect(interpolate("{a} and {b}", { a = "yes" })).toBe("yes and {b}")
	end)

	it("returns the input unchanged when no placeholders are present", function()
		expect(interpolate("plain text", { name = "World" })).toBe("plain text")
	end)

	it("returns an empty string for empty input", function()
		expect(interpolate("", { name = "World" })).toBe("")
	end)

	it("ignores braces around invalid keys", function()
		expect(interpolate("{ spaced }", { spaced = "no" })).toBe("{ spaced }")
		expect(interpolate("{}", {})).toBe("{}")
		expect(interpolate("{a-b}", { ["a-b"] = "x" })).toBe("{a-b}")
	end)

	it("leaves an unmatched opening brace literal", function()
		expect(interpolate("hello {", {})).toBe("hello {")
	end)

	it("supports underscores and digits in keys", function()
		expect(interpolate("{place_id_1}", { place_id_1 = "12345" })).toBe("12345")
	end)

	it("escapes braces with a backslash", function()
		expect(interpolate("\\{name\\}", { name = "ignored" })).toBe("{name}")
	end)

	it("escapes a backslash with a backslash", function()
		expect(interpolate("path C:\\\\dir", {})).toBe("path C:\\dir")
	end)

	it("treats a trailing backslash as a literal", function()
		expect(interpolate("text\\", {})).toBe("text\\")
	end)

	it("emits both characters when a backslash precedes a non-special char", function()
		expect(interpolate("\\n", {})).toBe("n")
		expect(interpolate("a\\b", {})).toBe("ab")
	end)

	it("substitutes around escaped braces", function()
		expect(interpolate("\\{{name}\\}", { name = "World" })).toBe("{World}")
	end)

	it("substitutes adjacent placeholders", function()
		expect(interpolate("{a}{b}", { a = "X", b = "Y" })).toBe("XY")
	end)
end)
