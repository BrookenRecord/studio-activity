<div align="center">

# `✨ Studio Activity`

**A privacy-friendly Roblox Studio plugin that shows your activity on Discord.**

[![🔍 Static Code Analysis](https://github.com/grilme99/studio-activity/actions/workflows/analyze.yml/badge.svg)](https://github.com/grilme99/studio-activity/actions/workflows/analyze.yml) · [![🧪 Tests](https://github.com/grilme99/studio-activity/actions/workflows/test.yml/badge.svg)](https://github.com/grilme99/studio-activity/actions/workflows/test.yml)

[Download](https://github.com/grilme99/studio-activity/releases/latest) · [Report a bug](https://github.com/grilme99/studio-activity/issues)

</div>

## Demo

https://github.com/user-attachments/assets/0a7771f5-42ee-46dc-8fdb-9f7ad2bbc748

## What it does

Studio Activity shows your current Roblox Studio session as a Discord activity on your profile, including the place name and how long you've been working on it. It's for creators who want to share what they're building without leaving Studio. The plugin posts directly to Discord's Headless Sessions API over HTTPS, so it works inside Studio's sandboxed plugin environment with no extra desktop app required.

## Installation

Studio Activity isn't on the Creator Marketplace right now, so installation is a one-time manual step:

1. Download `StudioActivity.rbxm` from the [latest release](https://github.com/grilme99/studio-activity/releases/latest).
2. Open Roblox Studio.
3. Open the **Plugins** tab and click **Plugins Folder**. Studio opens the plugins directory in your file manager.
4. Drag `StudioActivity.rbxm` into that folder.
5. Restart Studio. The plugin appears in the **Plugins** tab as **Studio Activity**.
6. Click the plugin icon, follow the in-Studio onboarding flow, and link your Discord account.

To update later, download the new `.rbxm` and replace the existing file in your Plugins folder.

> [!WARNING]
> **Be careful what other local plugins you install.** Studio Activity stores your Discord access token in its local plugin settings. Roblox Studio doesn't sandbox locally-installed (`.rbxm`) plugins from each other, so any other local plugin you have installed can read those settings and exfiltrate the token. Combined with the broad `sdk.social_layer_presence` scope (see [below](#why-does-the-plugin-ask-for-so-many-discord-permissions)), a malicious local plugin could use the stolen token to read or modify your Discord friends list. Only install local plugins from sources you trust.

## Privacy & telemetry

Studio Activity collects **anonymous, opt-in usage data**. You're asked during onboarding whether to enable it, and you can toggle it off whenever you want from plugin settings.

**Why I collect it.** I maintain Studio Activity on my own in my spare time. Telemetry is my only way to find out when an OAuth flow breaks for some chunk of users, or when a Studio update regresses presence updates. Without it, bugs that break onboarding can sit in a release for weeks before anyone files an issue. I keep the event list narrow on purpose: only what I need to spot regressions and prioritize fixes.

**What's collected.** Only the events listed below, plus a few build attributes:

- Lifecycle: `pluginLoaded`, `pluginUnloaded`, `uiOpened`, `onboardingCompleted`
- Account linking: `accountLinkStarted`, `accountLinked`, `deviceCodeFlowFailed`, `browserFlowFailed`, `accountRemoved`
- Presence: `presenceToggled`, `profileSelected`, `sessionError`
- Plugin version, channel, and build hash
- A SHA-256 hash of your Roblox user ID, computed locally. It can't be reversed back to a username.
- Your IP address, forwarded to PostHog only for bot detection and country-level geo enrichment. PostHog is configured to discard IPs after processing them.

**What is _not_ collected.** Roblox usernames, place names, place IDs, game content, file paths, system information, Discord usernames, Discord tokens, or any free-form text you type into the plugin.

**Where it goes.** Events are sent to a small Cloudflare Worker I run (source in [`backend/`](backend/)). The worker validates them and forwards them to PostHog. The complete event schema is defined in [`protos/api/v1/api.proto`](protos/api/v1/api.proto); the plugin can't send anything that isn't in that file.

If you'd rather not contribute telemetry, leave the toggle off in plugin settings. The plugin works identically either way.

## Why does the plugin ask for so many Discord permissions?

When you link your Discord account, Discord will ask you to authorize the **`sdk.social_layer_presence`** scope. That scope is broader than what the plugin actually uses. Here's why.

Roblox Studio plugins run in a sandbox and can't speak Discord's local RPC protocol that desktop apps use. The only way to update Discord activity from inside Studio is to POST to Discord's **Headless Sessions API**. To call that API, Discord requires the `sdk.social_layer_presence` OAuth scope, which is an umbrella scope for the Social SDK. It grants more than activity writes: it also lets an app connect to Discord's gateway on your behalf and read and write your relationships (your friends list).

**What Studio Activity actually uses.** Only the activity-write portion. It doesn't connect to the gateway, and it never reads or modifies your friends list. Your Discord access token is stored locally in Studio and never leaves your machine; my backend doesn't see it. Every Discord API call the plugin makes is in [`plugin/src/Api/Discord.luau`](plugin/src/Api/Discord.luau) (look for `createHeadlessSessionAsync`, `updateHeadlessSessionAsync`, and `deleteHeadlessSessionAsync`), with the orchestration in [`plugin/src/PresenceManager/createPresenceManager.luau`](plugin/src/PresenceManager/createPresenceManager.luau).

**I asked Discord to narrow it.** I emailed Discord Developer Support to ask whether my application could be granted the narrower `activities.write` scope directly, so the plugin could request only what it needs. They declined. The full exchange is below.

<details>
<summary><b>Discord support transcript</b></summary>

**Brooke:**

```
Hi team,

I'm building a Rich Presence integration between Discord and Roblox Studio, so game creators can display what they are working on in their Discord profile. The integration utilizes the Headless Sessions API to update activity data over HTTP (since Roblox Studio plugins are sandboxed and cannot communicate to Discord via RPC.)

However, to use the Headless Sessions API, I'm currently required to request the `sdk.social_layer_presence` scope via OAuth. This is an umbrella scope for the Social SDK, and while it does grant activity write, it also grants several permissions alongside presence updates, including:

- Connecting to the gateway on behalf of a user (implying persistent connection capabilities that this integration does not need)
- Reading and writing a user's relationships

From a security standpoint, this scope is far too broad for my use case. If possible, I'd like to request that my application be granted access to the `activities.write` scope directly, so I don't have to rely on the broader Social SDK scope.

Kind regards,
Brooke.
```

**Discord Support:**

```
Hey Brooke,

Unfortunately, we are unable to grant your app the activities.write OAuth2 scope. We apologize for the inconvenience, but please bear in mind that these scopes are not usually granted, and that the functionality they enable is not intended to be readily available.

Thanks for your patience on this, and please let us know if you have any further questions or concerns.

Regards,
Don Jinwoo
```

**Brooke:**

```
Hi Don,

Thanks for getting back to me. I'm a little confused by the reasoning here though.

The `sdk.social_layer_presence` scope is public and already implicitly grants `activities.write`. Since the Social SDK scope is openly available, the functionality behind `activities.write` is already readily accessible to any developer — I'm just asking to use it without the additional permissions I don't need.

As it stands, I can achieve the exact same result through the Social SDK scope, but doing so means requesting far more account access than my integration actually requires. Granting `activities.write` directly would be the more restrictive option for the end user.

Best,
Brooke.
```

**Discord Support:**

```
Hi Brooke,

I understand your confusion. While I wish I could something more, the decision is out of my hands. If you truly wish to access the activities.write scope, then utilizing our Social SDK would be your best option.

Thanks for understanding!

Cheers,
Don Jinwoo
```

</details>
