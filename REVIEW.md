# Codebase Review — studio-rich-presence

> Thorough structural review in preparation for open-sourcing.
> Generated: 2026-04-04

---

## Table of Contents

1. [Major Systems](#major-systems-identified)
2. [System 1: Plugin Infrastructure & Boot](#system-1-plugin-infrastructure--boot)
3. [System 2: Authentication & Account Flow](#system-2-authentication--account-flow)
4. [System 3: Presence Management & Activity](#system-3-presence-management--activity)
5. [System 4: UI Layer](#system-4-ui-layer)
6. [System 5: Telemetry](#system-5-telemetry)
7. [System 6: Build Tooling & CI](#system-6-build-tooling--ci)
8. [Cross-System Observations](#cross-system-observations)
9. [Open-Source Readiness Checklist](#open-source-readiness-checklist)

---

## Major Systems Identified

| # | System | Key Paths |
|---|--------|-----------|
| 1 | **Plugin Infrastructure & Boot** | `plugin/bin/`, `Plugin/`, `BuildVars/` |
| 2 | **Authentication & Account Flow** | `Authentication/`, `AddAccountFlow/`, `Api/` |
| 3 | **Presence Management & Activity** | `PresenceManager/`, `ActivityPreview/`, `PlaceContextStore/` |
| 4 | **UI Layer** | `MainScreen/`, `Common/`, `Modal/`, `Notification/`, `QRCode/`, `UserSettings/` |
| 5 | **Telemetry** | `Telemetry/` |
| 6 | **Build Tooling & CI** | `.lune/`, `.github/`, config files |

---

## System 1: Plugin Infrastructure & Boot

**Summary:** Bootstraps the plugin via a three-phase sequence: eager headless init (PluginStore, PresenceManager, ProfileStore), deferred UI load on first user interaction (createPluginLoader), and React mount (createPresencePlugin). Uses Charm signals/computed for state, Foundation for design system, and BuildVars for compile-time config.

### Critical

| File | Line(s) | Issue |
|------|---------|-------|
| All store `init.luau` files (8+) | — | **`Charm.computed` used as singleton factory** relies on the library never re-executing a zero-dependency computed. The entire state layer depends on this undocumented behavior. A simple lazy-init pattern (`if not instance then instance = create() end`) would be explicit and safe. |
| `setup.luau`, `createPluginLoader.luau`, `setupMain.luau` | 33, 237, 16 | **Three separate `plugin.Unloading` handlers** with no ordering guarantees. Roblox signal execution order is non-deterministic. If the loader handler fires before setup's, the interaction event unblocks, potentially starting React mount during teardown. |

### Warnings

| File | Line(s) | Issue |
|------|---------|-------|
| `setupMain.luau` | 8-9 | **`_G.__DEV__` and `_G.__LOG_LEVEL__` set too late.** Logger.luau evaluates these at `require`-time during the eager phase in `setup.luau`. By the time `setupMain` sets them, Logger is already configured without dev sinks and with `Warning` level. |
| `setupMain.luau` | 8 | **`_G.__DEV__ = true` hardcoded.** Ships to production unless the build pipeline patches it. |
| `createPluginSettingsStore.luau` | 113-125 | **Write effect fires before load completes.** On boot: write effect sees `storage ~= prevStorage` (nil), writes defaults to disk. If plugin crashes before load finishes, saved settings are lost. |
| `createPluginSettingsStore.luau` | 97-125 | **Load/write race condition.** Both effects spawn threads that yield. No guarantee load completes before write fires. |
| `BuildVars.json` | 2-4 | **Dev defaults in source:** `host: "localhost:8787"`, `secure: false`, `isDev: true`. No documentation on what build step replaces these. |
| `PluginApp.luau` | 22 | **`enabled` state starts `true`** but dock widget starts with `initialEnabled = false` — implicit coupling. |
| `createPresencePlugin.luau` | 69-70 | **Dead commented-out connection cleanup code.** Suggests missing cleanup logic. |

### Suggestions

| File | Line(s) | Issue |
|------|---------|-------|
| `setup.luau` | 11,41,58,59 | "StudioActivity" hardcoded in 4 places — use a constant. |
| `createPluginLoader.luau` | 13-63 | `createBufferedSignal` is a general utility embedded in a loader module — extract. |
| `createPluginSettingsStore.luau` | 40,80 | `readPluginSettingsAsync`/`writePluginSettingsAsync` are not async — misleading names. |
| `BuildVars/Types.luau` | — | `build.isDev` and `_G.__DEV__` are two unconnected dev-mode concepts. |

---

## System 2: Authentication & Account Flow

**Summary:** Implements Discord OAuth2 Device Code Flow. Users scan a QR code or paste a URL to authorize. Tokens are persisted via `Plugin:SetSetting`. The AccountStore caches user profile details and avatars. The Api layer provides typed HTTP wrappers with a Result monad.

### Critical

| File | Line(s) | Issue |
|------|---------|-------|
| Entire auth system | — | **Token refresh is never implemented.** `refreshTokenAsync` exists in `Discord.luau` but is never called. `expiresAt` is stored but never checked. After 7 days, all API calls 401 with no recovery path or user feedback. |
| `DeviceCodeFlow.luau` | 83-110 | **Duplicates the Discord API layer.** Has its own `postForm` helper, URL encoding, JSON parsing, and error handling — completely bypassing `Discord.luau`, `Result.luau`, and their typed error unions. Two divergent HTTP implementations in the same codebase. |
| `StartPage/BrowserFlow.luau` | 68 | **Hardcoded URL with embedded session token** (`https://presence.brooke.sh/start/pjGXMs9OPcBh`). Not connected to the device code flow at all. Placeholder/dev code committed to source. |

### Warnings

| File | Line(s) | Issue |
|------|---------|-------|
| `DeviceCodeFlow.luau` | 227 | **`refreshToken` type mismatch.** `AuthStore.Account` requires `string`, but `TokenResult` declares `string?`. If Discord omits it, nil is stored and the validator rejects on next load. |
| `DeviceCodeFlow.luau` | 210 | **`os.clock()` vs wall-clock `expiresIn`.** `os.clock()` measures process CPU time. If Studio is suspended, the deadline won't advance, causing polling to continue with an expired code. Should use `os.time()`. |
| `DeviceCodeFlow.luau` | 178-180 | **Wrong error field.** Checks `body.message` but OAuth errors use `body.error_description`. Users see "Request failed (400)" instead of the actual error. |
| `Discord.luau` | 446, 485 | **No 429 handling** on `getCurrentUserAsync` / `getUserAvatarAsync`. Rate-limit `retry_after` is lost. |
| `AccountStore` | 237-244 | **`addUserAsync` silently fails.** Returns void. `DeviceCodeFlow` transitions to `"authorized"` regardless of whether the account was actually stored. |
| `AuthContext.luau` | 56-63 | **Stale `props.onClose`** captured in Charm effect (deps: `{}`). |
| `BrowserFlow.luau` | — | **Entire component is static/non-functional.** Not connected to auth state. |
| `RetryBackoff.luau` | — | **Well-tested but never imported anywhere.** Should be wired into DeviceCodeFlow polling, AccountStore fetching, PresenceManager heartbeat. |

### Suggestions

| File | Line(s) | Issue |
|------|---------|-------|
| `Discord.luau` | 25 | Module-level `HttpService` import prevents DI for testing (unlike DeviceCodeFlow which accepts it via config). |
| `Discord.luau` | 496 | Snowflake precision loss on default avatar index for IDs > 2^53. |
| `PhoneFlow.luau` | 38 | No UI handling for `"expired"` or `"denied"` states. |
| `StatusUpdate.luau` | — | Always static — doesn't reflect actual auth status. |

---

## System 3: Presence Management & Activity

**Summary:** Manages the Discord presence lifecycle. PlaceContextStore gathers Roblox place metadata. ProfileStore manages presets and custom profiles that define how place context maps to Discord activity. PresenceManager owns the Discord session: create/update/delete with debounced sync and 15-minute heartbeat. ActivityPreview renders a live preview with web-fetched PNG images.

### Critical

| File | Line(s) | Issue |
|------|---------|-------|
| `WebImage.luau` | 83 | **`setHasError(false)` runs unconditionally** after the error branch sets it to `true`. Error state is immediately overwritten. The error fallback UI never renders for processing failures. Must be in an `else` branch. |
| `createPresenceManager.luau` | 255, 403 | **Race condition between heartbeat and sync effect.** Both read/write `sessionTokens` across yields with no mutex. Heartbeat can resurrect a session the user just deleted. |
| `createPresenceManager.luau` | 135, 270 | **`sessionStartedAt` never reset to nil.** Line 270's nil check is dead code. Timer doesn't reset when presence is toggled off/on. |

### Warnings

| File | Line(s) | Issue |
|------|---------|-------|
| `ActivityImage.luau` | 37-42 | **Small image block is an empty View.** No `WebImage` child is rendered for `smallImage` URLs. Incomplete implementation. |
| `ActivityImage.luau` | 32 | **Hardcoded fallback URL** from a different Discord app ID (`709530901058420776`). Could break; raises IP/licensing questions for open-source. |
| `createProfileStore.luau` | 137 | **Side effect inside `Charm.computed`.** `setActiveProfile("default")` is called during a computed derivation — an anti-pattern that risks cascading re-evaluations. |
| `createProfileStore.luau` | 189-207 | **`addCustomProfile` and `updateCustomProfile` are identical.** Character-for-character duplicate code. |
| `useWebImage.luau` | 48 | **Strict `content-type == "image/png"`** rejects valid responses like `"image/png; charset=utf-8"`. |
| `createPlaceContextStore.luau` | 23 | **Third-party `roproxy.com` proxy dependency.** Supply-chain risk. Community-run, could be compromised/shut down. |
| `ActivityTimer.luau` | 33-36 | **Timer start time disconnected from actual session.** Uses `os.time()` at mount, not `sessionStartedAt`. Acknowledged TODO. |

### Suggestions

| File | Line(s) | Issue |
|------|---------|-------|
| `Types.luau` | — | `Activity` type duplicated in 3+ places across the codebase. |
| `useWebImage.luau` | — | No in-memory image cache; no HTTP timeout. |
| `ActivityPreview.story.luau` | 27-30 | Empty string URLs trigger failing HTTP requests in stories. |

---

## System 4: UI Layer

**Summary:** React (Luau) components using Foundation design system. MainScreen is the primary widget view. Charm stores manage modal queue, notifications, and user settings. QRCode is a pure-Luau QR generator writing to `EditableImage`.

### Critical

| File | Line(s) | Issue |
|------|---------|-------|
| `DiscordAvatar.luau` | 64 | **Same `setHasError(false)` bug as `WebImage.luau`.** Error state unconditionally overwritten. Copy-paste bug present in two files. |
| `AccountEntry.luau` | 63-66 | **`Charm.computed` created inside render body.** Allocates a new computed signal every render. Old ones are never disposed. Memory leak that degrades over time. |

### Warnings

| File | Line(s) | Issue |
|------|---------|-------|
| `Notification.luau` | 27, 54 | **`TweenInfo` recreated every render.** New reference in dependency array causes the 4-second auto-dismiss effect to re-fire constantly. Notification may never auto-dismiss. |
| `Notification.luau` | 33-41 | **`props.onClose` missing from `useCallback` deps.** Stale closure risk. |
| `Notification.luau` | 40 | **`task.delay(0.1, props.onClose)` not cancelled on unmount.** Fires against stale context. |
| `Footer.luau` / `VersionTag.luau` | 57 / 37-42 | **Dev tools and "Dev Build" badge always rendered.** `DeveloperMenu` exposes "Print Plugin Storage" which dumps auth tokens. Must be gated behind `BuildVars.build.isDev`. |
| `AccountEntry.luau` | 209-215 | **"Re-link" button is a no-op.** `onActivated = function() end` — users see a clickable button that does nothing. |
| `QRCodeDisplay.luau` | 37 | **`getResolutionScale()` called every render.** Performs pcalls into GuiService/UserInputService. DPI doesn't change during session. |
| `usePlugin.luau` | 10 | **Doesn't subscribe to plugin signal changes.** Reads `getPlugin()` imperatively without reactive subscription. |
| `AccountList.luau` | 20-74 | **React elements created inside `Charm.computed` at module scope.** Couples state management with view layer. Elements are produced even when the component isn't mounted. |

### Suggestions

| File | Line(s) | Issue |
|------|---------|-------|
| Various | — | Inconsistent `React.memo` usage. Some leaf components are wrapped, others are not. |
| `AccountList.luau` | 63 | Magic number `3` for max accounts, unexplained. |
| `Header.luau` | 54-58 | Empty `Text` element used as spacer — use a `View`. |
| `SettingRow.luau` | 90 | `useMemo` depends on entire `userSettings` table — recomputes all rows on any change. |
| `createModalStore.luau` | 82-108 | `openAsync` has no timeout/cancellation. Leaked threads if modal never closes. |

---

## System 5: Telemetry

**Summary:** Builds anonymized usage events and sends them to a backend. SHA-256 hashes the Roblox UserId. Users can opt out via a dialog/settings. **The HTTP transport is entirely commented out — the system is non-functional.**

### Critical

| File | Line(s) | Issue |
|------|---------|-------|
| `getAnonymizedUserId.luau` | 16 | **Unsalted SHA-256 on a small integer keyspace.** Roblox UserIds are sequential integers (~5B range). The entire space can be brute-forced in under an hour on commodity hardware. For open-source code where the hashing scheme is public, this provides zero anonymization. Must use HMAC-SHA256 with a secret salt, or anonymize server-side. |

### Warnings

| File | Line(s) | Issue |
|------|---------|-------|
| `fireEventAsync.luau` | 18-32 | **HTTP transport commented out.** `_body` is constructed but never sent. Function named "Async" but is synchronous. Dead code. |
| `fireEventAsync.luau` | 20 | **Unsafe `(event :: any).properties`** bypasses type safety. Events without properties send `nil`. |
| `TelemetryOptOutDialog.luau` | 47-56 | **Opt-out event never sends.** Setting is written to `false` before the event fires, so `fireEventAsync`'s check short-circuits. Opt-in event works only by timing coincidence. |
| `DefaultSettings.luau` | 79 | **Default opt-in** (`value = true`). Dialog pre-checks the box. For open-source with global reach, defaulting to opt-in is a dark pattern (GDPR concerns). |
| `Types.luau` | 66-76 | `ApiError.endpoint` field could leak internal URL paths if raw URLs are passed. |

### Suggestions

| File | Line(s) | Issue |
|------|---------|-------|
| `Types.luau` | 1 | Typo: `TelementryEventName` → `TelemetryEventName`. |
| `fireEventAsync.luau` | — | No timestamp or session ID in event payload. |
| `getLocalUserId.luau` | 12 | Fallback `-1` makes all unresolved users share one anonymized ID. |
| `TelemetryOptOutDialog.luau` | 66 | Pressing outside dialog saves current state (opt-in) — should cancel instead. |

---

## System 6: Build Tooling & CI

**Summary:** Lune-based CLI (`setup`, `install`, `dev`, `ci`, `codegen`, `patch`) orchestrating Rojo, Wally, selene, stylua, and luau-lsp. Single GitHub Actions workflow for CI. Architecture is clean: thin entry points delegate to command modules with shared libs and utils.

### Critical

| File | Line(s) | Issue |
|------|---------|-------|
| `.env.example.luau` | — | **Missing `DISCORD_CLIENT_ID`.** New contributor copies `.env.example.luau`, runs `lune run setup`, hits an `assert` crash in `inject-build-vars.luau`. Blocks onboarding entirely. |
| `analyze.yml` + `inject-build-vars.luau` | 36 / 19 | **CI doesn't provide `DISCORD_CLIENT_ID`.** Only `ROBLOX_API_KEY` is in the workflow env. `codegen` → `injectBuildVars` → `assert` crash. CI is likely broken. |

### Warnings

| File | Line(s) | Issue |
|------|---------|-------|
| `inject-build-vars.luau` | 29 | **`isDev` hardcoded to `true`** even for production builds. `production` flag controls `api.secure` and `api.host` but misses `isDev`. |
| `inject-build-vars.luau` | 26 | **`version` hardcoded to `"0.0.1"`.** Never derived from `wally.toml`'s `0.1.0` or git tags. |
| `ci.luau` | 85 | **`globalTypes.d.luau` fetched from unpinned `master` branch.** Upstream breaking changes silently break CI. Pin to a specific commit hash. |
| `ci.luau` / `exec.luau` | 55-58 / 33 | **`shell = true` used unconditionally.** Injection surface if args ever come from external input. Non-portable. |
| `foundation.luau` | 34, 54, 69 | **Shells out to `find`, `realpath`, `cp`.** Non-portable (Windows). Use Lune's `fs` API. |
| `foundation.luau` | 41 | **Hardcoded React version** `jsdotlua_react@17.2.1` in string replacement. Must be kept in sync with `wally.toml`. |
| `install/init.luau` | 155 | **Hardcoded `/tmp/roblox-packages`** path. Won't work on Windows. |
| `analyze.yml` | 30-31 | `rm .luaurc` will fail if file doesn't exist. Should be `rm -f`. |
| `analyze.yml` | — | **No test step** despite Jest/JestGlobals in `wally.toml`. |
| `commands/dev.luau` | 45-78 | **No keepalive** after `task.spawn`. Process may exit immediately. No graceful Ctrl+C handling. |
| `wally.toml` | 25-29 | **Dev deps in `[dependencies]`** instead of `[dev-dependencies]`. Included in production installs. |
| `errors.luau` | 42 | Local `error` shadows global built-in. |
| `create-spinner.luau` | — | **Dead code.** Never imported anywhere. |
| `dev.luau` (entry) | 24 | `projectName` arg parsed but never registered or used. Dead code. |
| `patch.luau` | 120 | `fs.removeDir(.git)` unguarded — could throw. |
| `install/init.luau` | 100 | Variable `installStdout` actually holds stderr. Misleading. |

### Suggestions

| File | Line(s) | Issue |
|------|---------|-------|
| `help.luau` | 62 | Branding mismatch: "Studio Activity CLI" vs "studio-rich-presence". |
| `codegen/init.luau` | 19 | Stale description: "sourcemap only for now" but also does build vars and protos. |
| `cspell.json` | 13 | Typo in word list: `"xmsall"` → `"xsmall"`. |
| `rokit.toml` | — | Rojo pinned to release candidate `7.7.0-rc.1`. |

---

## Cross-System Observations

These are the patterns and issues that span multiple systems and represent the highest-impact improvements.

### 1. `setHasError(false)` Bug (Copy-Paste, 2 Files)

Both `WebImage.luau:83` and `DiscordAvatar.luau:64` have the identical bug:

```luau
if not success then
    setHasError(true)
    -- log error
end
setHasError(false) -- <-- always runs, overwriting the error
```

This is clearly copy-pasted code. Both error fallback UIs (`ErrorIcon`) are dead for processing failures. Fix in both files by moving `setHasError(false)` into an `else` branch or before the `pcall`.

### 2. Fragile Singleton Pattern (8+ Files)

Every store uses `Charm.computed(createStore)` as a singleton factory:

```luau
return { get = Charm.computed(createSomeStore) }
```

This works only because `Charm.computed` memoizes results when there are no reactive dependencies inside. This is load-bearing reliance on undocumented library behavior. Affected: `PluginStore`, `AccountStore`, `AuthStore`, `PresenceManager`, `ProfileStore`, `PlaceContextStore`, `ModalStore`, `NotificationStore`, `LocalStorageStore`. Replace with explicit lazy-init.

### 3. Dual Dev-Mode Flags (Never Synchronized)

- `_G.__DEV__` — set in `setupMain.luau`, consumed by `Logger.luau`
- `BuildVars.build.isDev` — set in `BuildVars.json`, consumed by... nothing checked
- `inject-build-vars.luau` hardcodes `isDev = true` regardless of production flag

These should be unified. `BuildVars.build.isDev` should be the single source of truth, set correctly by the build pipeline, and `_G.__DEV__` should be derived from it before any modules are loaded.

### 4. No Token Refresh (Auth ↔ Presence)

The auth system stores `expiresAt` and `refreshToken` but never checks or uses them. The presence manager sends API calls with access tokens that silently expire after 7 days. Users get silent failures with no explanation. This needs either proactive token refresh or clear UI feedback when tokens expire.

### 5. Unordered Plugin Lifecycle (Boot ↔ Mount ↔ Teardown)

Cleanup is scattered across three files with implicit ordering contracts. A single `PluginLifecycle` module that owns the ordered startup/shutdown sequence would prevent the documented race conditions during `plugin.Unloading`.

### 6. Duplicate Activity Type Definitions

The `Activity` / `ActivityConfig` shape is defined in:
- `ActivityPreview/Types.luau`
- `createPresenceManager.luau` (`ActivityConfig`, `ActivityConfigAssets`)
- `LocalStorageStore.luau` (implicit via custom profile storage)

If a field is added to one, the others must be manually updated. Consolidate into a single shared types module.

### 7. Missing Error Recovery Everywhere

- DeviceCodeFlow: transient 500 immediately terminates polling (no retry)
- AccountStore.addUserAsync: fails silently
- WebImage/DiscordAvatar: error UI broken (finding #1)
- AccountEntry "Re-link" button: no-op
- PresenceManager: no retry on failed session creation/update

`RetryBackoff.luau` is well-tested but completely unused. Wire it in.

### 8. Third-Party Supply-Chain Risk

- `roproxy.com` for Roblox thumbnails (community proxy, can be compromised)
- `ActivityImage` fallback from another Discord app's CDN assets
- CI fetches `globalTypes.d.luau` from unpinned `master` branch

All should be documented prominently, and ideally replaced with first-party alternatives or configurable endpoints.

### 9. React-Luau Pitfalls

- `Charm.computed` inside render body (`AccountEntry.luau:63`) — memory leak
- `TweenInfo` recreated every render (`Notification.luau:27`) — effect re-fires
- `props.onClose` missing from deps (`Notification.luau:33`)
- `ref.current` as effect dep (`useRefProperty.luau:26`) — never triggers
- React elements created inside `Charm.computed` at module scope (`AccountList.luau:20`)
- Mixed approaches to state subscription (`usePlugin` reads imperatively vs. reactively)

### 10. CI/Build Pipeline Gaps

- CI is likely broken (missing `DISCORD_CLIENT_ID`)
- No test execution despite Jest being a dependency
- Dev dependencies shipped in production (`[dependencies]` vs `[dev-dependencies]`)
- Version never derived from source of truth
- Non-portable shell commands (`find`, `realpath`, `cp`, `/tmp/`)

---

## Open-Source Readiness Checklist

### Blockers

- [ ] **README** — No README exists. Must have: what this is, screenshots, setup instructions, architecture overview.
- [ ] **LICENSE** — No LICENSE file. Required for any open-source release.
- [ ] **`.env.example.luau` incomplete** — Missing `DISCORD_CLIENT_ID`. New contributors crash on setup.
- [ ] **Hardcoded session token** in `BrowserFlow.luau:68` — must be removed or made dynamic.
- [ ] **Unsalted user ID hashing** — trivially reversible anonymization. Must use HMAC or server-side anonymization.
- [ ] **Hardcoded fallback URL** from foreign Discord app in `ActivityImage.luau:32`.
- [ ] **`isDev = true` always** — production builds ship with dev mode. No functional production config path.
- [ ] **CI broken** — missing env var causes assertion failure.

### Should Fix

- [ ] Token refresh implementation
- [ ] `setHasError(false)` bug in 2 files
- [ ] `Charm.computed` memory leak in AccountEntry
- [ ] Notification auto-dismiss broken by TweenInfo recreation
- [ ] DeveloperMenu (token-dumping) gated behind dev flag
- [ ] Default telemetry opt-in → opt-out
- [ ] Unify dev-mode flags
- [ ] Plugin lifecycle ordering

### Nice to Have

- [ ] CONTRIBUTING.md with architecture overview
- [ ] Wally `[dev-dependencies]` separation
- [ ] Image caching for web images
- [ ] Cross-platform build scripts (remove `find`/`realpath`/`cp`/`/tmp/`)
- [ ] Wire RetryBackoff into polling and API calls
- [ ] Test execution in CI
- [ ] Consolidate Activity type definitions
- [ ] Add privacy policy link to telemetry dialog
