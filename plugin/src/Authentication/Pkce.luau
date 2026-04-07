--[[
	Pkce

	Generates a (codeVerifier, codeChallenge) pair for the OAuth2
	Authorization Code + PKCE flow (RFC 7636, S256 method).

	Roblox doesn't ship a crypto module, so we:
	  • derive 32 random bytes from two HttpService GUIDs (each ≈122 bits),
	  • base64url-encode them (no padding) to form the verifier,
	  • SHA-256 the verifier and base64url-encode the digest for the challenge.

	The dekkonot/sha256 package is already vendored (used by Telemetry).
	Its second return value is the digest as 8 unsigned 32-bit integers,
	which we pack into raw bytes via string.pack to avoid re-parsing the
	hex string back into bytes.
]]

local HttpService = game:GetService("HttpService")

local Plugin = script:FindFirstAncestor("StudioActivity")
local Packages = Plugin.Packages
local sha256 = require(Packages.sha256)

local Pkce = {}

export type Keys = {
	codeVerifier: string,
	codeChallenge: string,
}

-- Standard base64 alphabet, but with `+`/`/` swapped for `-`/`_` per
-- RFC 4648 §5. Padding (`=`) is omitted, also per RFC 7636 §4.2.
local BASE64URL_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local function charAt(sextet: number): string
	return string.sub(BASE64URL_ALPHABET, sextet + 1, sextet + 1)
end

local function base64UrlEncode(bytes: string): string
	local out = table.create(math.ceil(#bytes / 3) * 4)
	local len = #bytes

	-- Process complete 3-byte groups → 4 base64 chars.
	local i = 1
	while i + 2 <= len do
		local b1, b2, b3 = string.byte(bytes, i, i + 2)
		local n = bit32.bor(bit32.lshift(b1, 16), bit32.lshift(b2, 8), b3)
		table.insert(out, charAt(bit32.rshift(n, 18)))
		table.insert(out, charAt(bit32.band(bit32.rshift(n, 12), 0x3f)))
		table.insert(out, charAt(bit32.band(bit32.rshift(n, 6), 0x3f)))
		table.insert(out, charAt(bit32.band(n, 0x3f)))
		i += 3
	end

	-- Tail: 1 or 2 remaining bytes → 2 or 3 base64 chars (no padding).
	local remaining = len - i + 1
	if remaining == 1 then
		local b1 = string.byte(bytes, i)
		local n = bit32.lshift(b1, 16)
		table.insert(out, charAt(bit32.rshift(n, 18)))
		table.insert(out, charAt(bit32.band(bit32.rshift(n, 12), 0x3f)))
	elseif remaining == 2 then
		local b1, b2 = string.byte(bytes, i, i + 1)
		local n = bit32.bor(bit32.lshift(b1, 16), bit32.lshift(b2, 8))
		table.insert(out, charAt(bit32.rshift(n, 18)))
		table.insert(out, charAt(bit32.band(bit32.rshift(n, 12), 0x3f)))
		table.insert(out, charAt(bit32.band(bit32.rshift(n, 6), 0x3f)))
	end

	return table.concat(out)
end

--[[
	Compute the PKCE S256 challenge for an existing verifier:
	  challenge = base64url(SHA256(verifier)),  no padding
]]
local function deriveChallenge(codeVerifier: string): string
	local _hex, words = sha256(codeVerifier)
	-- Pack the 8 u32 digest words into 32 raw bytes (big-endian).
	local digestBytes =
		string.pack(">I4I4I4I4I4I4I4I4", words[1], words[2], words[3], words[4], words[5], words[6], words[7], words[8])
	return base64UrlEncode(digestBytes)
end

--[[
	Build a new verifier + challenge pair.

	Verifier construction (matches RFC 7636 §4.1's recommendation of
	base64url(32 random octets)):
	  1. Generate two v4 GUIDs and concatenate the hex (64 hex chars).
	  2. Decode to 32 raw bytes.
	  3. base64url-encode → 43 chars, no padding.
]]
function Pkce.generate(): Keys
	local guidA = HttpService:GenerateGUID(false)
	local guidB = HttpService:GenerateGUID(false)
	local hex = string.gsub(guidA .. guidB, "-", "")

	local bytes = table.create(32)
	for i = 1, 32 do
		bytes[i] = string.char(tonumber(string.sub(hex, i * 2 - 1, i * 2), 16) :: number)
	end
	local randomBytes = table.concat(bytes)

	local codeVerifier = base64UrlEncode(randomBytes)
	local codeChallenge = deriveChallenge(codeVerifier)

	return {
		codeVerifier = codeVerifier,
		codeChallenge = codeChallenge,
	}
end

-- Exposed for unit tests (RFC 7636 Appendix B vectors).
Pkce._deriveChallenge = deriveChallenge
Pkce._base64UrlEncode = base64UrlEncode

return Pkce
