# T3 Code sessions integration (fork feature)

This fork adds a **T3 tab** to the notch showing live [T3 Code](https://github.com/pingdotgg/t3code)
agent threads, plus notch notifications when an agent needs approval or input,
finishes, or fails. Everything talks to the local T3 Code server over its
loopback HTTP API — no t3code fork or patching involved.

## Using it

1. Have T3 Code running (desktop app — release or nightly — or `npx t3`).
2. In boring.notch settings, open **T3 Code** and enable the integration.
3. That's it for the local server: the fork **pairs itself** — it mints a
   one-time pairing credential directly in the t3 server's own store
   (`~/.t3/userdata/statev2.sqlite` on protocol v2, `state.sqlite` on legacy servers,
   exactly what `t3 pair` does) and exchanges
   it for a 30-day bearer token (scope `orchestration:read`) in the Keychain.
   Tokens re-mint automatically on expiry. Manual pairing-link entry remains
   as a fallback when `~/.t3` isn't writable.
4. If your server uses a non-default port, change it in the same pane
   (default 3773).

Auto-pairing is why this fork **disables the App Sandbox**
(`boringNotch/boringNotch.entitlements`): the app needs to read/write
`~/.t3`. Note the sandboxed stable app and this fork therefore use different
preference stores (container vs `~/Library/Preferences`) — migrate once with
`defaults export theboringteam.boringnotch /tmp/bn.plist && defaults import
~/Library/Preferences/theboringteam.boringnotch.plist /tmp/bn.plist &&
killall cfprefsd`.

### Remote machines

Each T3 Code server represents one machine. To see sessions from
other machines (LAN/Tailscale), add them under **Remote Macs** in the settings
pane (`host:port`), pair each one with a pairing link minted **on that
machine**, and their sessions appear in their own group in the T3 tab. The
settings pane shows the real T3 Code app icon, loaded at runtime from the
installed bundle (no trademark assets are vendored into the repo).

## Installing as a standalone app

`scripts/install.sh` builds a Release copy and installs it to
**/Applications/boringNotch (T3).app** — launch it from Spotlight or the Dock
like any app, no Xcode needed. Re-run the script after pulling changes to
update it. It builds and verifies an ad-hoc signed replacement before quitting
or replacing the installed app. A failed build leaves the installed app alone. Settings →
About shows the installed fork’s Git revision, so builds with the same upstream
version can be distinguished.

It installs beside the stock `/Applications/Boring Notch.app` (formerly
`boringNotch.app`) rather than replacing it; they share a bundle id (hence shared settings) and must not run
at the same time (both drive the notch). Quit the stock app before launching
this one, and vice-versa.

## Developing alongside the stable app

The dev build and the stable `/Applications/Boring Notch.app` share a bundle id,
so they fight over the notch and must not run at once (they *share* settings
and pairing, which is convenient). `scripts/dev.sh` handles the swap: quits
stable, builds, runs the dev build in the foreground, and relaunches stable
when it exits.

The fork disables Sparkle’s stock update service and replaces its settings with
a link to the fork repository. Pull fork changes and run `scripts/install.sh`
to update; stock upstream releases would remove the T3 integration.

## How it works

- `T3SessionsManager` probes `GET /.well-known/t3/environment` to detect the
  server and its protocol version, then polls `GET /api/orchestration/shell`
  every 3 s while connected. Protocol v2 requests send
  `x-t3-orchestration-protocol: 2`. Legacy remote servers remain supported.
- Each thread is mapped to a phase (`waiting_for_approval`, `waiting_for_input`,
  `running`, `completed`, `failed`, …) by `T3AgentAwareness` — a Swift port of
  t3code's own `packages/shared/src/agentAwareness.ts` (MIT). Subagent rows are
  hidden, activity-owning runs take precedence, and monitors/subagents keep
  completion pending while long-lived commands do not.
- Phase transitions into actionable states raise a closed-notch notification via
  `BoringViewCoordinator.toggleExpandingView(type: .t3)`.
- The session list and home widget keep a stable order during streaming, input
  and approval changes. A session moves to the front only when a turn finishes;
  new sessions append without displacing existing ones. Temporary disconnections
  preserve the order until the integration is stopped or the app restarts.

## Launching T3 Code with the control channel

Opening a session **in the desktop app** needs T3 Code running with
`--remote-debugging-port=9223` (its Electron build has no deep-link handler;
boring.notch navigates it over that local CDP channel by setting the
renderer's `location.hash` — the desktop routes threads in the hash). Three
ways it launches correctly:

- Click a session in the notch while T3 isn't running — boring.notch launches
  it with the flag (the T3 tab's "isn't running" state also has a Launch
  button).
- Use **/Applications/T3 Code Launcher.app** (created for this fork — an
  AppleScript applet wearing the T3 icon) as the Dock / login item instead of
  the real app.
- After a plain Dock launch, use the "Relaunch T3 Code" button in
  Settings → T3 Code.

Launched any other way, session clicks fall back to the T3 web app in the
browser. Protocol v2 threads use `/threads/{environmentId}/{threadId}`; desktop
navigation uses that path in the renderer’s hash. When stable and nightly are
both installed, the running app takes precedence.

## Keeping up with upstream

The upstream baseline is `upstream/main` (https://github.com/TheBoredTeam/boring.notch);
the feature lives on `t3-sessions`. To update:

```sh
git fetch upstream
git checkout -b update/boring-notch t3-sessions
git merge upstream/main
# Verify, push the update branch, and open a PR into t3-sessions.
```

All feature code lives in `boringNotch/private/T3Sessions/` — the `private/`
folder is a filesystem-synchronized Xcode group, so these files are compiled
without any `project.pbxproj` changes and can never conflict. The only upstream
files this fork touches (a few lines each — re-apply by hand if a merge ever
mangles them):

| File | Change |
|---|---|
| `boringNotch/enums/generic.swift` | `case t3Sessions` in `NotchViews` |
| `boringNotch/components/Tabs/TabSelectionView.swift` | conditional T3 tab entry |
| `boringNotch/ContentView.swift` | tab `switch` case, closed-notch alert branch, chin width |
| `boringNotch/BoringViewCoordinator.swift` | `case t3` in `SneakContentType` |
| `boringNotch/components/Notch/BoringHeader.swift` | show tab bar when T3 is enabled |
| `boringNotch/components/Settings/SettingsView.swift` | settings nav link + pane case |
| `boringNotch/boringNotchApp.swift` | start `T3SessionsManager` at launch |
| `boringNotch/Info.plist` | fork marker to disable stock Sparkle updates |
| `boringNotch/components/Settings/SoftwareUpdater.swift` | fork update links in place of stock update controls |
| `boringNotch/boringNotch.entitlements` | App Sandbox disabled (auto-pairing needs `~/.t3`) |
| `boringNotch/components/Tabs/TabButton.swift` | draw the T3 glyph for the sentinel icon token |
| `boringNotch/models/BoringViewModel.swift` | sticky T3 tab guard in `close()` |
| `boringNotch/components/Notch/NotchHomeView.swift` | optional T3 widget in the calendar slot |

The Swift compiler enforces most of these: `NotchViews` and `SneakContentType`
switches are exhaustive, so a lost edit shows up as a build error, not silent
breakage.

## t3code API stability

Run `scripts/test-t3.sh` for decoding, state, background-work and route fixtures.
With the local server running, `scripts/test-t3.sh --live` also performs a
read-only shell poll using the app’s local pairing flow. Credentials remain
in memory and are never printed.

T3 Code is alpha; its REST contracts (`packages/contracts/src/environmentHttp.ts`)
can change across protocol versions. Optional additions and unknown fields are
ignored, while protocol changes need explicit compatibility updates. If a poll
starts failing after a T3 update, diff the contracts first.
