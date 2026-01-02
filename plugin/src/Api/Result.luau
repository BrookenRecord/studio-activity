export type Ok<T> = {
	ok: true,
	value: T,
}

export type Err<E> = {
	ok: false,
	error: E,
}

export type Result<T, E> = Ok<T> | Err<E>

local Result = {}

--[[
	Creates a successful result.
]]
function Result.ok<T>(value: T): Ok<T>
	return {
		ok = true,
		value = value,
	}
end

--[[
	Creates an error result.
]]
function Result.err<E>(error: E): Err<E>
	return {
		ok = false,
		error = error,
	}
end

--[[
	Unwraps a result, returning the value if ok or throwing if error.
	@param result The result to unwrap
	@param errorMessage Optional custom error message
]]
function Result.unwrap<T, E>(result: Result<T, E>, errorMessage: string?): T
	if result.ok then
		return result.value
	else
		error(errorMessage or tostring(result.error))
	end
end

--[[
	Unwraps a result, returning the value if ok or a default value if error.
]]
function Result.unwrapOr<T, E>(result: Result<T, E>, default: T): T
	if result.ok then
		return result.value
	else
		return default
	end
end

--[[
	Maps a successful result's value using the provided function.
]]
function Result.map<T, U, E>(result: Result<T, E>, fn: (T) -> U): Result<U, E>
	if result.ok then
		return Result.ok(fn(result.value))
	else
		return result :: any
	end
end

--[[
	Maps an error result's error using the provided function.
]]
function Result.mapErr<T, E, F>(result: Result<T, E>, fn: (E) -> F): Result<T, F>
	if result.ok then
		return result :: any
	else
		return Result.err(fn(result.error))
	end
end

return Result
