local Plugin = script:FindFirstAncestor("StudioActivity")

local Authentication = Plugin.Source.Authentication
local Packages = Plugin.Packages
local JestGlobals = require(Packages.Dev.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Pkce = require(Authentication.Pkce)

describe("Pkce", function()
	describe("base64UrlEncode", function()
		it("encodes empty input as empty string", function()
			expect(Pkce._base64UrlEncode("")).toBe("")
		end)

		it("encodes single byte without padding", function()
			-- 0x00 → 6+2 bits → "AA"
			expect(Pkce._base64UrlEncode("\0")).toBe("AA")
		end)

		it("encodes two bytes without padding", function()
			-- 0xff 0xff → "//+8" in std b64 → "__8" in url-safe (no padding)
			expect(Pkce._base64UrlEncode("\xff\xff")).toBe("__8")
		end)

		it("encodes three bytes as four chars", function()
			-- "ABC" (0x41 0x42 0x43) → standard b64 "QUJD"
			expect(Pkce._base64UrlEncode("ABC")).toBe("QUJD")
		end)

		it("uses url-safe alphabet (no + or /)", function()
			-- 0xfb 0xff → "+/" in std b64; should become "-_" in url-safe
			-- Note: 0xfb 0xff produces "+/8" in std → "-_8" url-safe (no pad)
			expect(Pkce._base64UrlEncode("\xfb\xff")).toBe("-_8")
		end)

		it("encodes 32 bytes to 43 chars (no padding)", function()
			local bytes = string.rep("\0", 32)
			expect(#Pkce._base64UrlEncode(bytes)).toBe(43)
		end)
	end)

	describe("deriveChallenge (RFC 7636 Appendix B)", function()
		it("matches the canonical S256 test vector", function()
			-- Per RFC 7636 Appendix B:
			--   verifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
			--   challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
			local verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
			local expected = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
			expect(Pkce._deriveChallenge(verifier)).toBe(expected)
		end)
	end)

	describe("generate", function()
		it("returns a verifier matching [A-Za-z0-9_-]{43}", function()
			local keys = Pkce.generate()
			expect(#keys.codeVerifier).toBe(43)
			expect(string.match(keys.codeVerifier, "^[A-Za-z0-9_-]+$")).toBe(keys.codeVerifier)
		end)

		it("returns a 43-char challenge", function()
			local keys = Pkce.generate()
			expect(#keys.codeChallenge).toBe(43)
			expect(string.match(keys.codeChallenge, "^[A-Za-z0-9_-]+$")).toBe(keys.codeChallenge)
		end)

		it("challenge is the SHA-256 of the verifier (round-trip)", function()
			local keys = Pkce.generate()
			expect(Pkce._deriveChallenge(keys.codeVerifier)).toBe(keys.codeChallenge)
		end)

		it("returns distinct values across calls", function()
			local a = Pkce.generate()
			local b = Pkce.generate()
			expect(a.codeVerifier).never.toBe(b.codeVerifier)
		end)
	end)
end)
