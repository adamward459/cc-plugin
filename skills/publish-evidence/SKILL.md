---
name: publish-evidence
description: Read the notes, screenshots, and videos a case file has under .argent/recordings/ and publish them as one comment on a PR, uploading the files through Claude in Chrome. Covers every case, whether record-evidence or manual-test-walkthrough wrote its note. Use whenever the user wants test evidence posted on a PR. Never posts without a yes.
argument-hint: "<case-file> [pr-number]"
disable-model-invocation: true
---

# Publish Evidence

Reads a case file's evidence and publishes it as one PR comment. Nothing else: it never records,
never edits notes or the case file, and never changes a result. The evidence folder is
`.argent/recordings/<area>/`, where `<area>` is the case file's folder under `spec/testcases/`.

Note fields: `Result`, `Driven by`, `Evidence`.

## Invocation

- `<case-file>` — from the arguments, or the case file named in the conversation. Ask for it only
  when neither has one.
- `<pr-number>` — from the arguments, else the current branch's PR (`gh pr view --json number,url`).

Needs Claude in Chrome (`mcp__claude-in-chrome__*` tools). The GitHub CLI cannot make attachment
links; only the user's logged-in browser can. When those tools are missing, stop and tell the user
to restart with `claude --chrome` (a launch flag, not an in-session command). The in-app browser
and the chrome-devtools MCP lack the user's GitHub login, so a private repo gives a 404.

## 1. Build the block

1. Read the case file. The rows are every `Status: active` case × each of its `Targets`.
2. For each row, read `<ID>-<target>/note.md` in the evidence folder, and list its
   `<ID>-<target>-*.png` screenshots and its `<ID>-<target>.mp4` video.
3. Write the block to the scratchpad as `pr-evidence-<slug>.md`:
   - First line: `VERIFIED X of N; NOT VERIFIED N−X (reason)`. X counts notes with
     `Result: pass`. A row with no note is NOT-RUN, and it is listed, never dropped.
   - Sections `## 📱 Mobile (iOS)` and `## 📱 Mobile (Android)`, only those with rows.
   - Per case: `### <ID> — <title>`, then `**Result: ✅ pass**` or `**Result: ❌ fail**`,
     `Driven by`, and the `Evidence` labels as the note has them. On fail, copy "What I saw" as it
     is.
   - When the note has a `## Server check` section, one line from it under the result.
   - Screenshots as an HTML `<table>`, 3 per row (`<td width="33%">`). Pad a short last row with
     empty `<td>`. Under each row, a second `<tr>` with
     `<td align="center"><sub>Caption</sub></td>`; the caption comes from the `<state>` part of
     the file name (`SS1-ios-2-sentences-tab.png` → `Sentences tab`).
   - The video in `<details><summary>🎥 <ID> — <title></summary>`, after the shots.
   - Every image `src` and video link is a placeholder: `{{<file name>}}`.

## 2. Confirm

Show the target PR, the block, and the files to upload with their sizes. Wait for a yes. The
upload sends the files to GitHub and the comment is public.

## 3. Upload in Chrome

1. `navigate` to the PR URL. The upload button does not accept `file_upload`, so in
   `javascript_tool` un-hide `#fc-new_comment_field` and give it `aria-label="evidence upload"`.
   Then `find` "evidence upload" for its ref.
2. `file_upload` the absolute file paths to that ref, in batches of at most 10 MB.
3. Wait for the links in `#new_comment_field`'s `value`. Poll with separate short
   `javascript_tool` calls; one call that loops with `await` hits the 45 s limit. An 8 MB video
   takes about 40 s. It is done when there is one link per file and no "Uploading" text.
4. Match each link to a file:
   - Screenshot: GitHub inserts `<img … alt="<file name>" src="https://github.com/user-attachments/assets/<id>" />`,
     not markdown `![]()`. The `alt` is the file name, with or without `.png`.
   - Video: a bare link on its own line, and the order is not the upload order. Match by byte
     size: `curl -sL -o /dev/null -w '%{size_download}' -H "Authorization: token $(gh auth token)" <link>`
     against `stat -f '%z' <file>`. When two sizes are equal or a link matches no file, ask which
     video it is; never guess.
5. Clear the draft: set the textarea `value` to `""` and dispatch an `input` event. Never press
   Comment in the browser.

## 4. Post

1. Replace every placeholder in the block with its link. Use only the `src` link, not the
   `width` and `height` GitHub adds; the `<td width>` sizes the image. If a placeholder is still
   open, stop and list it.
2. `gh pr comment <number> --body-file <block>`, or, to update an earlier evidence comment,
   `gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id> -F body=@<block>`.
3. Give the comment link.

## Rules

- Copy results from the notes. Never change a result, and never mark a row pass without a note.
- The block holds no headers, tokens, or passwords. `server.txt` is summarized from the note's
  `Server check` section, never pasted whole.
- The block lives in the scratchpad, never in `.argent/recordings/` or the repo.
