---
name: publish-evidence
description: Read the notes, screenshots, and videos a case file has under .evidence/ and publish them as one comment on a pull request or merge request, on GitHub, GitLab, or any other git host. Uploads the files through the comment box in Claude in Chrome, the same way on every platform. Use whenever the user wants test evidence posted on a PR or MR. Never posts without a yes.
argument-hint: "<case-file> [pr-or-mr-number-or-url]"
disable-model-invocation: true
---

# Publish Evidence

Reads a case file's evidence and publishes it as one comment on a PR (GitHub) or MR (GitLab), or
the same thing on another git host. Nothing else: it never records, never edits notes or the case
file, and never changes a result.

The evidence folder is `.evidence/<KEY>/`, where `<KEY>` is the case file name without its
extension (`specs/testcases/AO-702.md` → `AO-702`; for a generic name like `cases` or `README`,
the folder name). Each case has `.evidence/<KEY>/<ID>/` with files named `<ID>-<target>…`:

```text
<ID>-<target>.md                the note: Result, Driven by, Proof, Checks, Server check, What I saw
<ID>-<target>.mp4               the video, for a video case
<ID>-<target>-<n>-<state>.png   screenshots, when there are any
<ID>-<target>-server.txt        raw server check output; never posted
```

## Invocation

- `<case-file>`: from the arguments, or the case file named in the conversation. Ask for it only
  when neither has one.
- `<pr-or-mr>`: a number or URL from the arguments, else the current branch's PR or MR (table
  below). On an Other host, ask for the URL when the arguments have none.

### Platform

Take the host from `git remote get-url origin`, then pick the row:

| Platform | When                                                              | Find the current one                            | Post                                                                                 | Update an earlier comment                                                       |
| -------- | ----------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| GitHub   | `github.com`, or `gh auth status --hostname <host>` passes        | `gh pr view --json number,url`                  | `gh pr comment <n> --body-file <block>`                                              | `gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id> -F body=@<block>`    |
| GitLab   | host has `gitlab`, or `glab auth status --hostname <host>` passes | `glab mr view --output json` (`iid`, `web_url`) | `glab api -X POST projects/:id/merge_requests/<iid>/notes -F body=@<block>`          | `glab api -X PUT projects/:id/merge_requests/<iid>/notes/<id> -F body=@<block>` |
| Other    | anything else (Bitbucket, Azure DevOps, Gitea, Forgejo, …)        | ask the user for the URL                        | the user posts: put the final block in the comment box and ask them to press Comment | the user edits the comment by hand                                              |

Say "PR" or "MR" as the platform does.

### Chrome

Needs Claude in Chrome (`mcp__claude-in-chrome__*` tools). GitHub has no API for comment
attachments, so uploads go through the comment box in the user's logged-in browser. The same steps
work on every host, so one method covers all of them. When those tools are missing, stop and tell
the user to restart with `claude --chrome` (a launch flag, not an in-session command). The in-app
browser and the chrome-devtools MCP lack the user's login, so a private repo gives a 404.

## 1. Build the block

1. Read the case file. Read its fields by meaning: targets can be platform columns, `Platform`,
   `Targets`, `Device`. The cases are every case not marked removed (`🚫` in every cell), inactive,
   draft, or deprecated. The rows to verify are each case × each of its targets.
2. For each case × target, read `<ID>/<ID>-<target>.md` in the evidence folder, and list its
   `<ID>-<target>-*.png` screenshots and its `<ID>-<target>.mp4` video.
3. Write the block to the scratchpad as `pr-evidence-<KEY>.md`:
   - First line: `VERIFIED X of N; NOT VERIFIED N−X (reasons)`. N counts case × target. X counts
     notes with `Result: pass` on cases that are not outdated. A target with no note is not run,
     and it is listed, never dropped. A pass on an outdated case is not verified: its steps
     changed after the recording.
   - Then one HTML `<table>`, the same shape as the case table `extract-test-cases` writes, so a
     reviewer sees every case at a glance and expands only the ones they care about:
     - Columns: `ID`, `Case`, one per platform the cases use (`Web`, `iOS`, `Android`), `Proof`.
     - One row per case, in this order: current cases (★ first, then by ID), then outdated cases.
     - Platform cells: `✅ pass`, `❌ fail`, `⏳ not run` (no note), `⚠️ outdated`, or `—` when the
       case does not run there.
     - Proof cell: `🎥` when the case has a video, else `📷`.
     - Case cell: `<details><summary>` with the title (keep the ★), collapsed. Inside it, for each
       target, in column order:
       - `**<Target>: ✅ pass**`, `**<Target>: ❌ fail**`, or `**<Target>: ⏳ not run**`, then
         `Driven by` as the note has it.
       - When the note has a `## Server check` section, one line from it.
       - The note's checks as a list. On fail, copy "What I saw" as it is.
       - Screenshots as an HTML `<table>`, 3 per row (`<td width="33%">`). Pad a short last row
         with empty `<td>`. Under each row, a second `<tr>` with
         `<td align="center"><sub>Caption</sub></td>`; the caption comes from the `<state>` part
         of the file name (`SS1-ios-2-sentences-tab.png` → `Sentences tab`).
       - The video as `{{video:<file name>}}` on its own line.
     - Every image `src` is a placeholder: `{{<file name>}}`.
   - Leave a blank line after each `<summary>` line, around each video line, and before each
     `</details>`, and do not indent the lines between them. Without the blank lines GitHub shows
     the Markdown as raw text and the video gets no player.

## 2. Confirm

Show the platform, the PR link, how it will be posted (the Post column), the block, and the
files to upload with their sizes. When the project docs say manual test evidence goes on the
final PR only, also ask whether this is the feature's final PR. Wait for a yes. The upload sends the files to the host, and the
comment is visible to everyone who can see the PR.

## 3. Upload in Chrome

1. `navigate` to the PR or MR page. Find the new-comment textarea and its file input with
   `javascript_tool`. Selectors change, so check them in the page; these are where they were last
   seen:
   - GitHub: textarea `#new_comment_field`, input `#fc-new_comment_field`.
   - GitLab: textarea `#note-body`. The input is in its form, or a Dropzone
     `input.dz-hidden-input` at the end of `<body>`.
   - Other: the `input[type=file]` in the textarea's `closest('form')`. When you cannot tell which
     input belongs to the comment box, stop and say what you found.

   The attach button does not accept `file_upload`, so un-hide the input and give it
   `aria-label="evidence upload"`. Then `find` "evidence upload" for its ref.

2. `file_upload` the absolute file paths to that ref, in batches of at most 10 MB.
3. Wait for the links in the textarea's `value`. Poll with separate short `javascript_tool` calls;
   one call that loops with `await` hits the 45 s limit. An 8 MB video takes about 40 s. It is done
   when there is one link per file and no "Uploading" text.
4. Match each link to a file by the file name in what the host inserted:
   - GitHub image: `<img … alt="<file name>" src="https://github.com/user-attachments/assets/<id>" />`.
     The `alt` is the file name, with or without `.png`.
   - GitLab: `![<name>](/uploads/<hash>/<file name>)`, for images and videos alike.
   - GitHub video: a bare link on its own line, with no file name, and the order is not the upload
     order. Match by byte size:
     `curl -sL -o /dev/null -w '%{size_download}' -H "Authorization: token $(gh auth token)" <link>`
     against `stat -f '%z' <file>`.
   - When two sizes are equal, or a link matches no file, ask which file it is; never guess.
5. Clear the draft: set the textarea `value` to `""` and dispatch an `input` event. Never press
   Comment in the browser.

## 4. Post

1. Fill the block:
   - `{{<file name>}}` gets the image URL only. Drop the `width` and `height` the host adds; the
     `<td width>` sizes the image.
   - `{{video:<file name>}}` gets the whole line the host inserted for that video (GitHub: the bare
     link; GitLab: the `![…](…)` line).
   - Keep each link exactly as inserted. A GitLab `/uploads/…` path is relative to the project and
     works in any comment on it.
   - If a placeholder is still open, stop and list it.
2. Post with the platform's Post command, or its Update command to replace an earlier evidence
   comment. On an Other host, set the textarea `value` to the filled block, dispatch an `input`
   event, and ask the user to review it and press Comment.
3. Give the comment link, or on an Other host, say the draft is ready in the browser.

## Rules

- Copy results from the notes. Never change a result, and never mark a row pass without a note.
- The block holds no headers, tokens, or passwords. `<ID>-<target>-server.txt` is summarized
  from the note's `Server check` section, never pasted whole.
- The block lives in the scratchpad, never in `.evidence/` or the repo.
