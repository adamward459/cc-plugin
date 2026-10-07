# Usage: python3 grade.py <workspace>/iteration-N [with_skill,old_skill]
import json, re, sys
from pathlib import Path

it = Path(sys.argv[1])
CONFIGS = sys.argv[2].split(",") if len(sys.argv) > 2 else ["with_skill", "old_skill"]


def section(text, title):
    m = re.search(rf"^## {title}.*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def case(text, tc):
    m = re.search(rf"^### {tc} .*?(?=^### |^## |\Z)", text, re.M | re.S)
    return m.group(0) if m else ""


def rows(table_text):
    return [r for r in table_text.splitlines() if re.match(r"\|\s*B-\d+", r)]


def manual_cases(text):
    return re.findall(r"^### TC-\d+", section(text, "Test Cases") or text, re.M)


def common(text, at_path, path_name, process, asked=''):
    beh = rows(section(text, "Behaviors"))
    tcs = manual_cases(text)
    tc_blocks = [case(text, t[4:]) for t in tcs]
    return beh, tcs, tc_blocks, [
        (f"File saved at {path_name}", at_path, ""),
        ("Has a '## Setup' section", bool(re.search(r"^## Setup", text, re.M)), ""),
        ("Has a Behaviors table", len(beh) > 0, f"{len(beh)} rows"),
        ("Every behavior has coverage full/partial/none",
         bool(beh) and all(re.search(r"\b(full|partial|none)\b", r) for r in beh), ""),
        ("Every test case links to behaviors",
         bool(tc_blocks) and all(re.search(r"Behaviors?: B-\d+", b) for b in tc_blocks), ""),
        ("Case list is focused (3-12 cases)", 3 <= len(tcs) <= 12, f"{len(tcs)} cases"),
        ("No Questions section in the file", not re.search(r"^## Questions", text, re.M), ""),
        ("No open-question pointers in Expected", not re.search(r"\bQ-\d", section(text, "Test Cases")), ""),
        ("Asked the user before writing (questions.md)", bool(asked.strip()), asked.strip()[:200]),
        ("User answers used as sources", 'Answer "' in section(text, "Behaviors"), ""),
        ("Cases are not labeled manual/automated/human",
         not re.search(r"\b(manual|automated|human)\b", section(text, "Test Cases"), re.I), ""),
        ("Behavior and coverage steps ran in subagents",
         bool(re.search(r"subagent|agent", process, re.I)) and not re.search(r"could not spawn|spawned none|did not spawn", process, re.I),
         process.strip()[:200]),
    ]


def checks_web(text, at_path, process):
    asked = ASKED
    beh, tcs, blocks, out = common(text, at_path, "specs/testcases/AO-618.md", process, asked)
    kyc = [r for r in beh if "AC-5" in r or "Complete KYC" in r]
    minimum = [r for r in beh if re.search(r"10 USD|[Mm]inimum", r)]
    out += [
        ("Setup names the NEXT_PUBLIC_FIAT_WITHDRAW_V2 flag", "NEXT_PUBLIC_FIAT_WITHDRAW_V2" in section(text, "Setup"), ""),
        ("Behavior sources include requirement ACs and code lines",
         any("AC-" in r for r in beh) and any(re.search(r"\.tsx?:\d+", r) for r in beh), ""),
        ("Every AC-1..AC-7 is in the Behaviors table", all(any(f"AC-{i}" in r for r in beh) for i in range(1, 8)), ""),
        ("KYC behavior is full coverage with no manual case",
         bool(kyc) and all("full" in r and "TC-" not in r for r in kyc), " / ".join(kyc)[:200]),
        ("Minimum-amount behavior is partial and has a manual case",
         bool(minimum) and any("partial" in r and "TC-" in r for r in minimum), ""),
        ("Steps use real UI labels", '"Continue"' in text and "Amount (USD)" in text, ""),
        ("No password or token values", not re.search(r"password\s*[:=]\s*\S+|token\s*[:=]\s*\S+", text, re.I), ""),
    ]
    return out


def checks_mobile(text, at_path, process):
    asked = ASKED
    beh, tcs, blocks, out = common(text, at_path, "specs/testcases/AO-702.md", process, asked)
    manual = section(text, "Test Cases")
    out += [
        ("Setup names the otp_resend_v2 remote config", "otp_resend_v2" in section(text, "Setup"), ""),
        ("Platform covers ios and android", "Platform: ios, android" in text, ""),
        ("Behavior sources are code lines only",
         bool(beh) and all(re.search(r"\.tsx?:\d+", r) for r in beh) and not any("Jira" in r for r in beh), ""),
        ("No invented AC numbers", not re.search(r"\bAC-\d", text), ""),
        ("Cases for cooldown and lockout", "Resend code in" in manual and "Too many attempts" in manual, ""),
        ("Edge cases for background and failed resend",
         bool(re.search(r"background", manual, re.I) and re.search(r"fail|offline|airplane", manual, re.I)), ""),
    ]
    return out


def checks_update(text, at_path, process):
    asked = ASKED
    beh, tcs, blocks, out = common(text, at_path, "specs/testcases/AO-618.md", process, asked)
    out = [o for o in out if not o[0].startswith("Manual list")]
    tc1, tc2 = case(text, "TC-1"), case(text, "TC-2")
    questions = section(text, "Questions")
    out += [
        ("TC-1, TC-2, TC-3 keep their IDs", all(case(text, t) for t in ("TC-1", "TC-2", "TC-3")), ""),
        ("TC-2 result lines unchanged", "Status: pass" in tc2 and "TC-2/recording.webm" in tc2 and "DBS ••••1234" in tc2, ""),
        ("TC-1 now expects the 20 USD minimum", "20 USD" in tc1, ""),
        ("TC-1 is Status: outdated", "Status: outdated" in tc1, ""),
        ("TC-1 keeps its old Note", "Typed 5 and clicked Continue" in tc1, ""),
        ("TC-1 has an Outdated: reason line", bool(re.search(r"^- Outdated:", tc1, re.M)), ""),
        ("New case added for Withdraw all", bool(re.search(r"^### TC-([4-9]|\d\d) .*Withdraw all", text, re.M | re.I)), ""),
        ("Double fee on Withdraw all asked or raised",
         bool(re.search(r"withdraw all", questions + ASKED, re.I) and re.search(r"fee", questions + ASKED, re.I)), ""),
        ("KYC automation reference kept", "WithdrawForm.test" in text, ""),
    ]
    return out


TC2_RESULTS = """- ios:
  - Mode: agent
  - Status: pass
  - Recording: TC-2/ios.mp4
  - Note: Lockout text showed 15:00 and counted down.
- android:
  - Mode: agent
  - Status: pass
  - Recording: TC-2/android.mp4
  - Note: Same as iOS on a Pixel 7 emulator."""


def checks_mobile_update(text, at_path, process):
    beh, tcs, blocks, out = common(text, at_path, "specs/testcases/AO-702.md", process)
    out = [o for o in out if not o[0].startswith(("Asked the user", "User answers"))]
    tc1 = case(text, "TC-1")
    statuses = re.findall(r"^\s*- Status: (\S+)", tc1, re.M)
    out += [
        ("TC-1, TC-2, TC-3 keep their IDs", all(case(text, t) for t in ("TC-1", "TC-2", "TC-3")), ""),
        ("TC-1 now expects the 0:30 cooldown", "0:30" in tc1, ""),
        ("TC-1 has one Outdated: line", len(re.findall(r"^- Outdated:", tc1, re.M)) == 1, ""),
        ("TC-1 ios and android results are both Status: outdated",
         bool(re.search(r"^- ios:", tc1, re.M) and re.search(r"^- android:", tc1, re.M))
         and statuses == ["outdated", "outdated"], f"statuses: {statuses}"),
        ("TC-1 keeps both recordings and notes",
         all(s in tc1 for s in ("TC-1/ios.mp4", "TC-1/android.mp4", "then \"Resend code\" appeared", "froze at 0:41")), ""),
        ("TC-2 platform results unchanged", TC2_RESULTS in case(text, "TC-2"), ""),
    ]
    return out


CHECKS = {
    "eval-1-web-withdraw-with-requirement": ("specs/testcases/AO-618.md", checks_web),
    "eval-2-mobile-otp-diff-only": ("specs/testcases/AO-702.md", checks_mobile),
    "eval-3-update-existing-file": ("specs/testcases/AO-618.md", checks_update),
    "eval-4-mobile-update-per-platform-results": ("specs/testcases/AO-702.md", checks_mobile_update),
}

for name, (expected, fn) in CHECKS.items():
    for cfg in CONFIGS:
        run = it / name / cfg / "run-1"
        if not run.exists():
            continue
        outputs = run / "outputs"
        md = outputs / expected
        at_path = md.exists()
        if not at_path:
            mds = [m for m in outputs.rglob("*.md") if m.name not in ("final_message.md", "process.md", "questions.md")]
            md = mds[0] if mds else None
        text = md.read_text() if md else ""
        ASKED = (outputs / "questions.md").read_text() if (outputs / "questions.md").exists() else ""
        proc = (outputs / "process.md").read_text() if (outputs / "process.md").exists() else ""
        results = [{"text": t, "passed": bool(p), "evidence": e or (str(md.relative_to(run)) if md else "no file")}
                   for t, p, e in fn(text, at_path, proc)]
        passed = sum(r["passed"] for r in results)
        (run / "grading.json").write_text(json.dumps({
            "expectations": results,
            "summary": {"passed": passed, "failed": len(results) - passed, "total": len(results),
                        "pass_rate": round(passed / len(results), 2)},
        }, indent=2))
        print(f"{name:38} {cfg:12} {passed}/{len(results)}  " +
              "; ".join(r["text"] for r in results if not r["passed"]))
