# Web (Chrome DevTools)

All browser work goes through the `chrome-devtools-rec` MCP server. It runs with screencast on and its own Chrome profile (`--isolated`). Use only its tools for the whole run; another DevTools server drives a different browser.

## Per case

- **Start:** `new_page` with the start URL and keep its `pageId`. Never drive a page the user already has open.
- **State:** confirm the start state with `take_snapshot`.
- **Video:** `screencast_start` with `filePath` set to `<case folder>/<ID>-web.mp4`; the path must be inside the project, or the server refuses it.
- **Drive:** take a snapshot, act on the `uid` it lists with `click`, `fill` or `press_key`, and take a new snapshot after each page change. A `uid` from an old snapshot can point to the wrong element.
- **Check:** `wait_for` with the expected text, or find the element in `take_snapshot`. A disabled button shows as `disabled` in the snapshot.
- **Stop:** the screencast writes a frame only when the next one arrives, so the last change on a still page (often the result the case checks) is lost at stop. After the last check, read the page size with `evaluate_script` (`() => [window.innerWidth, window.innerHeight]`), `resize_page` to one pixel wider, then back to that size, and only then call `screencast_stop`. This flushes the final frame without touching the app. Use the inner size: `resize_page` sets the page size, so the window size leaves a black strip in the video. Stop the screencast even when a step fails, after the same flush.
- **Screenshot**, only when the user asks: `take_screenshot` with `filePath`.
- **Network:** `list_network_requests`, then `get_network_request` for one request. Copy the method, URL and status only. Headers and cookies hold session tokens.

## Clean up

Close the pages this run opened with `close_page`.
