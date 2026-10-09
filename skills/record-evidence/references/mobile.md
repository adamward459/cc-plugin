# iOS and Android (argent)

All device work goes through the `argent` MCP server. The same tools serve the iOS simulator and Android emulators or devices; each call takes the device id as `udid` (an iOS UDID or an Android serial). Each tool's own description is the full reference; this file is only the order of use.

## Device and app

- `list-devices`: pick a booted device of the target platform. With none, `boot-device` with the `udid` (iOS) or `avdName` (Android) from the list. Note which device this run booted.
- `launch-app` with the bundle id (iOS) or package name (Android). Find it in the Xcode project, `android/app/build.gradle` (`applicationId`) or `app.json`.
- App state: `reinstall-app` for a clean install, `restart-app`, `open-url` for a deep link, `settings-permissions` for a permission.

## Per case

- **Element tree:** `describe`. Frames are fractions of the screen (0–1). Tap the centre of a frame. Read the tree again after every screen change.
- **Drive:** `run-sequence` when every step is known in advance; single `gesture-tap`, `keyboard`, `gesture-swipe`, `button` calls when a step depends on what the last one showed.
- **Secrets:** type a password as `{{secret:<NAME>}}` in `keyboard` text, inside one `run-sequence` with the submit step. argent reads the value on its own side, so it never enters the conversation. In Phase 3, ask the user to add `ARGENT_SECRET_<NAME>=…` to `~/.argent/secrets.env` (or `.argent/secrets.env` in the project); a secrets file works at once, an env var needs a restart.
- **Check:** `await-ui-element` per expected line, with `condition` `visible`, `hidden` or `text`. Only `success: true` is a pass. `cause: unreadable` means nothing was judged: read the tree with `describe` and check again; do not fail the case on it.
- **Video:** `screen-recording-start` with `timeLimitSeconds` a little longer than the case. Stop it with `screen-recording-stop`, even when a step fails, and move the returned `video` file into the case folder as `<ID>-<target>.mp4`. Read its `warning` field and put any warning in the note. Then shrink the video with `scripts/fit-video.sh` (SKILL.md, Phase 4 step 5).
- **Screenshot**, only when the user asks: `screenshot`.
- **Network:** `view-network-logs`, then `view-network-request-details` for one request. Copy the method, URL and status only. Headers hold tokens.

## Clean up

`stop-all-simulator-servers` with `devices: [<ids this run used>]`. Never call it without `devices`: one argent tool-server serves every agent on the machine, and an unscoped call stops their devices too.
