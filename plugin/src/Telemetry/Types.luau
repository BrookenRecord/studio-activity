-- The events in this file mirror the TelemetryRequest oneof in the backend.
-- The backend must be updated first before adding new events.

export type PluginLoaded = {
	eventName: "PluginLoaded",
	properties: {
		accountCount: number,
		isPresenceActive: boolean,
		activeProfile: string,
	},
}

export type UiOpened = {
	eventName: "UiOpened",
}

export type OnboardingCompleted = {
	eventName: "OnboardingCompleted",
	properties: {
		optedIntoTelemetry: boolean,
	},
}

export type AccountLinkStarted = {
	eventName: "AccountLinkStarted",
}

export type AccountLinked = {
	eventName: "AccountLinked",
	properties: {
		accountCount: number,
		isFirstAccount: boolean,
	},
}

export type AccountLinkFailed = {
	eventName: "AccountLinkFailed",
	properties: {
		error: string,
	},
}

export type AccountRemoved = {
	eventName: "AccountRemoved",
	properties: {
		accountCount: number,
	},
}

export type PresenceToggled = {
	eventName: "PresenceToggled",
	properties: {
		isActive: boolean,
	},
}

export type ProfileSelected = {
	eventName: "ProfileSelected",
	properties: {
		profile: string,
	},
}

export type SessionError = {
	eventName: "SessionError",
	properties: {
		error: string,
	},
}

export type PluginUnloaded = {
	eventName: "PluginUnloaded",
}

export type TelemetryEvent =
	| PluginLoaded
	| UiOpened
	| OnboardingCompleted
	| AccountLinkStarted
	| AccountLinked
	| AccountLinkFailed
	| AccountRemoved
	| PresenceToggled
	| ProfileSelected
	| SessionError
	| PluginUnloaded

return nil
