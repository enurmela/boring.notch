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
   (`~/.t3/userdata/state.sqlite`, exactly what `t3 pair` does) and exchanges
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

T3 Code has no cloud sessions — one server is one machine. To see sessions from
other machines (LAN/Tailscale), add them under **Remote Macs** in the settings
pane (`host:port`), pair each one with a pairing link minted **on that
machine**, and their sessions appear in their own group in the T3 tab. The
settings pane shows the real T3 Code app icon, loaded at runtime from the
installed bundle (no trademark assets are vendored into the repo).

## Developing alongside the stable app

The dev build and the stable `/Applications/boringNotch.app` share a bundle id,
so they fight over the notch and must not run at once (they *share* settings
and pairing, which is convenient). `scripts/dev.sh` handles the swap: quits
stable, builds, runs the dev build in the foreground, and relaunches stable
when it exits. If you ever promote a fork build into `/Applications`, watch
out for Sparkle: its auto-update feed is upstream's and would overwrite the
fork with a stock release.

## How it works

- `T3SessionsManager` probes `GET /.well-known/t3/environment` to detect the
  server, then polls `GET /api/orchestration/shell` every 3 s while connected.
- Each thread is mapped to a phase (`waiting_for_approval`, `waiting_for_input`,
  `running`, `completed`, `failed`, …) by `T3AgentAwareness` — a Swift port of
  t3code's own `packages/shared/src/agentAwareness.ts` (MIT).
- Phase transitions into actionable states raise a closed-notch notification via
  `BoringViewCoordinator.toggleExpandingView(type: .t3)`.

## Keeping up with upstream

`main` mirrors `upstream/main` (https://github.com/TheBoredTeam/boring.notch);
the feature lives on `t3-sessions`. To update:

```sh
git fetch upstream
git checkout main && git merge --ff-only upstream/main
git checkout t3-sessions && git merge main
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
| `boringNotch/boringNotch.entitlements` | App Sandbox disabled (auto-pairing needs `~/.t3`) |

The Swift compiler enforces most of these: `NotchViews` and `SneakContentType`
switches are exhaustive, so a lost edit shows up as a build error, not silent
breakage.

## t3code API stability

T3 Code is alpha; its REST contracts (`packages/contracts/src/environmentHttp.ts`)
evolve additively (new fields decode as optional here, unknown fields are
ignored). If a poll starts failing after a T3 update, diff the contracts first.
