-- The events in this file mirror the TelemetryEventName enum in the backend.
-- The backend must be updated first before adding new events.

export type AppOpened = {
	eventName: "AppOpened",
}

export type AppClosed = {
	eventName: "AppClosed",
}

export type TelemetryOptedIn = {
	eventName: "TelemetryOptedIn",
}

export type TelemetryOptedOut = {
	eventName: "TelemetryOptedOut",
}

export type AuthStarted = {
	eventName: "AuthStarted",
	properties: {
		--- Whether the user already has credentials (linking additional account)
		hasExistingCredentials: boolean,
	},
}

export type AuthCompleted = {
	eventName: "AuthCompleted",
	properties: {
		--- Whether this was a new user (credentials were issued)
		isNewUser: boolean,
	},
}

export type AuthFailed = {
	eventName: "AuthFailed",
	properties: {
		--- The type of error that occurred
		errorType: string,
		--- The error code from the API (if available)
		errorCode: string?,
	},
}

export type PresenceUpdated = {
	eventName: "PresenceUpdated",
	properties: {
		--- Number of accounts successfully updated
		updatedCount: number,
		--- Number of accounts that failed to update
		failedCount: number,
	},
}

export type PresenceCleared = {
	eventName: "PresenceCleared",
	properties: {
		--- Number of accounts successfully cleared
		clearedCount: number,
		--- Number of accounts that failed to clear
		failedCount: number,
	},
}

export type ApiError = {
	eventName: "ApiError",
	properties: {
		--- The API endpoint that failed
		endpoint: string,
		--- The type of error
		errorType: string,
		--- HTTP status code (if applicable)
		statusCode: number?,
	},
}

export type RateLimited = {
	eventName: "RateLimited",
	properties: {
		--- The API endpoint that was rate limited
		endpoint: string,
		--- Retry-After value in seconds (if provided)
		retryAfter: number?,
	},
}

export type TelemetryEvent =
	| AppOpened
	| AppClosed
	| TelemetryOptedIn
	| TelemetryOptedOut
	| AuthStarted
	| AuthCompleted
	| AuthFailed
	| PresenceUpdated
	| PresenceCleared
	| ApiError
	| RateLimited

return nil
