# Usage: python3 grade.py <workspace>/iteration-N [with_skill,without_skill]
import json, re, socket, subprocess, sys
from pathlib import Path

it = Path(sys.argv[1])
CONFIGS = sys.argv[2].split(",") if len(sys.argv) > 2 else ["with_skill", "without_skill"]
DRIVING = r"xcrun\s+simctl\s+(boot|launch|io|install|openurl)|adb\s+(shell\s+input|install)|\bemulator\s+-avd"
PICKED = r"pick|to record|will record|selected|\*\*yes\*\*|\| yes|re-record"


def lines_with(text, case_id):
    return [l for l in text.splitlines() if re.search(rf"\b{case_id}\b", l)]


def said(text, case_id, pattern):
    hits = lines_with(text, case_id)
    return any(re.search(pattern, l, re.I) for l in hits), " / ".join(hits)[:200]


def git_status(repo):
    return subprocess.run(["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True).stdout.strip()


def load(run):
    out = run / "outputs"
    read = lambda n: (out / n).read_text() if (out / n).exists() else ""
    return read("response.md"), read("commands.txt")


def gate_common(run, cmds):
    repo = run / "repo"
    status = git_status(repo)
    return [
        ("Repo files unchanged (git status clean)", not status, status[:200]),
        ("No .evidence folder created", not (repo / ".evidence").exists(), ""),
        ("No xcrun simctl or adb used to drive the app", not re.search(DRIVING, cmds), ""),
    ]


def check_1(run):
    reply, cmds = load(run)
    return gate_common(run, cmds) + [
        ("Asks the user for a case file", bool(re.search(r"case file|test cases", reply, re.I)), ""),
        ("Writes no case file", not (run / "repo" / "specs").exists() and not (run / "repo" / "spec").exists(), ""),
    ]


def check_2(run):
    reply, cmds = load(run)
    return gate_common(run, cmds) + [
        ("TC-2 is picked (outdated on ios)", *said(reply, "TC-2", PICKED)),
        ("TC-6 is picked (no result yet)", *said(reply, "TC-6", PICKED)),
        ("TC-1 is skipped: already pass on ios", *said(reply, "TC-1", r"pass")),
        ("TC-3 is skipped: android only", *said(reply, "TC-3", r"android")),
        ("TC-4 is skipped: removed", *said(reply, "TC-4", r"removed")),
        ("TC-5 is BLOCKED: needs a person", *said(reply, "TC-5", r"block|person|manual|human")),
        ("Stops because the argent MCP server is not connected",
         bool(re.search(r"argent", reply, re.I) and re.search(r"not (connected|available|in (this|the) session|loaded|running)|missing|enable", reply, re.I)), ""),
    ]


def check_3(run):
    reply, cmds = load(run)
    return gate_common(run, cmds) + [
        ("SS1 is picked", *said(reply, "SS1", PICKED)),
        ("SS2 is BLOCKED: Driver human", *said(reply, "SS2", r"block|person|human|manual")),
        ("SS3 is skipped: ios only", *said(reply, "SS3", r"ios")),
        ("SS4 is skipped: inactive", *said(reply, "SS4", r"inactive")),
        ("Tells the user to add .evidence/ to .gitignore", ".evidence" in reply and "gitignore" in reply.lower(), ""),
    ]


def case_block(text, tc):
    m = re.search(rf"^### {tc} .*?(?=^### |^## |\Z)", text, re.M | re.S)
    return m.group(0) if m else ""


def check_4(run):
    reply, cmds = load(run)
    repo = run / "repo"
    ev = repo / ".evidence" / "AO-801"
    status = git_status(repo)
    case_file = (repo / "specs/testcases/AO-801.md").read_text()
    original = subprocess.run(["git", "show", "HEAD:specs/testcases/AO-801.md"], cwd=repo, capture_output=True, text=True).stdout
    tcs = ["TC-1", "TC-2", "TC-3"]
    videos = {tc: [f for f in (ev / tc).glob(f"{tc}-web.*") if f.suffix in (".mp4", ".webm", ".mov") and f.stat().st_size > 0] for tc in tcs}
    notes = {tc: (ev / tc / f"{tc}-web.md").read_text() if (ev / tc / f"{tc}-web.md").exists() else "" for tc in tcs}
    blocks = {tc: case_block(case_file, tc) for tc in tcs + ["TC-4"]}
    evidence_text = "\n".join(p.read_text(errors="ignore") for p in ev.rglob("*") if p.suffix in (".md", ".txt", ".log"))
    port = int(re.search(r"http\.server (\d+)", original).group(1))
    with socket.socket() as s:
        port_free = s.connect_ex(("127.0.0.1", port)) != 0
    return [
        ("Only the case file changed in the repo", status == "M specs/testcases/AO-801.md", status[:200]),
        ("No xcrun simctl or adb used to drive the app", not re.search(DRIVING, cmds), ""),
        ("Case folders exist for TC-1, TC-2, TC-3 and not TC-4",
         all((ev / tc).is_dir() for tc in tcs) and not (ev / "TC-4").exists(),
         str(sorted(p.name for p in ev.iterdir())) if ev.exists() else "no .evidence/AO-801"),
        ("Every case folder has a non-empty video named <ID>-web", all(videos.values()), str({k: [f.name for f in v] for k, v in videos.items()})),
        ("No screenshots when the case has a video",
         all(not list((ev / tc).glob("*.png")) for tc in tcs if videos[tc]), str({tc: len(list((ev / tc).glob("*.png"))) for tc in tcs})),
        ("Test recording removed (only case folders in .evidence/AO-801)",
         ev.exists() and all(p.is_dir() for p in ev.iterdir()), str(sorted(p.name for p in ev.iterdir())) if ev.exists() else ""),
        ("Every case folder has a note <ID>-web.md with a Result line", all(re.search(r"Result:", n) for n in notes.values()), ""),
        ("TC-1 and TC-3 notes say pass", all(re.search(r"Result:\s*\**pass", notes[t], re.I) for t in ("TC-1", "TC-3")), ""),
        ("TC-2 note says fail and quotes what it saw",
         bool(re.search(r"Result:\s*\**fail", notes["TC-2"], re.I) and re.search(r"Sent 120 USD", notes["TC-2"])), notes["TC-2"][:200]),
        ("Case file: TC-1..TC-3 have Mode, Status, Recording and Note lines",
         all(all(re.search(rf"- {f}:", blocks[t]) for f in ("Mode", "Status", "Recording", "Note")) for t in tcs), ""),
        ("Case file: TC-2 has Status: fail, TC-1 and TC-3 have Status: pass",
         bool(re.search(r"Status: fail", blocks["TC-2"]) and all(re.search(r"Status: pass", blocks[t]) for t in ("TC-1", "TC-3"))), ""),
        ("Case file: TC-4 is unchanged", blocks["TC-4"] == case_block(original, "TC-4"), ""),
        ("No secrets in evidence", not re.search(r"authorization:|bearer\s+\w|cookie:|password\s*[:=]\s*\S", evidence_text, re.I), ""),
        ("Web server stopped after the run", port_free, f"port {port}"),
    ]


CHECKS = {"1": check_1, "2": check_2, "3": check_3, "4": check_4}

for ev in sorted(it.glob("eval-*")):
    fn = CHECKS[ev.name.split("-")[1]]
    for run in sorted(r for cfg in CONFIGS for r in (ev / cfg).glob("run-*")):
        if not (run / "outputs").exists():
            continue
        exps = [{"text": t, "passed": bool(p), "evidence": e} for t, p, e in fn(run)]
        passed = sum(x["passed"] for x in exps)
        (run / "grading.json").write_text(json.dumps({
            "expectations": exps,
            "summary": {"passed": passed, "failed": len(exps) - passed, "total": len(exps),
                        "pass_rate": round(passed / len(exps), 2)},
        }, indent=2, ensure_ascii=False))
        print(f"{ev.name}/{run.parent.name}/{run.name}: {passed}/{len(exps)}")
