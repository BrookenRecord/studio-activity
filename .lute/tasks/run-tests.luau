local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- This path is defined in tests.project.json
local TestRunner = (require :: any)(ReplicatedStorage.StudioActivity.Bin.TestRunner)

TestRunner.runTests()

return nil
