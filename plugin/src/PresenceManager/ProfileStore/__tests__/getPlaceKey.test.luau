local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local JestGlobals = require(Packages.Dev.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local getPlaceKey = require(Plugin.Source.PresenceManager.ProfileStore.getPlaceKey)

describe("getPlaceKey", function()
	it("should use the experience id for online places", function()
		local key = getPlaceKey({
			placeType = "online",
			placeId = 123,
			experienceId = 456,
		})

		expect(key).toBe("online:456")
	end)

	it("should return different keys for different experiences", function()
		local firstKey = getPlaceKey({
			placeType = "online",
			placeId = 123,
			experienceId = 456,
		})

		local secondKey = getPlaceKey({
			placeType = "online",
			placeId = 123,
			experienceId = 789,
		})

		expect(firstKey).never.toBe(secondKey)
	end)

	it("should use the place name for local files", function()
		local key = getPlaceKey({
			placeType = "offline",
			placeId = 0,
			experienceId = 0,
			offlinePlaceDetails = {
				placeName = "Untitled Game",
			},
		})

		expect(key).toBe("local:Untitled Game")
	end)

	it("should fall back to the place id when an online experience id is unavailable", function()
		local key = getPlaceKey({
			placeType = "online",
			placeId = 123,
			experienceId = 0,
		})

		expect(key).toBe("online-place:123")
	end)
end)
