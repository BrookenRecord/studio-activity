local Types = require(script.Types)
export type BuildVars = Types.BuildVars

local CompiledBuildVars: BuildVars = require(script.BuildVars)
return table.freeze(CompiledBuildVars)
