#!/bin/bash
set -e
# Usage: make-repo.sh <no-case-file|extract-format|other-format|web-transfer> <dest> [port]
KIND="$1"
DEST="$2"
PORT="${3:-8765}"
[ -n "$KIND" ] && [ -n "$DEST" ] || { echo "Usage: make-repo.sh <kind> <dest>" >&2; exit 1; }
rm -rf "$DEST" && mkdir -p "$DEST" && cd "$DEST"
git init -q -b DEV
git config user.email qa@example.com
git config user.name QA

mkdir -p src
cat > package.json <<'EOF'
{ "name": "aqx-mobile", "private": true, "scripts": { "ios": "react-native run-ios", "android": "react-native run-android" },
  "dependencies": { "react": "18.2.0", "react-native": "0.74.0" } }
EOF
cat > app.json <<'EOF'
{ "name": "AqxMobile", "displayName": "AQX" }
EOF
cat > src/App.tsx <<'EOF'
import { Text } from 'react-native';
export default function App() {
  return <Text>AQX</Text>;
}
EOF
printf 'node_modules/\nios/Pods/\n' > .gitignore

if [ "$KIND" = "extract-format" ]; then
  printf '.evidence/\n' >> .gitignore
  mkdir -p specs/testcases
  cat > specs/testcases/AO-702.md <<'EOF'
# AO-702 - OTP resend

Source: diff `feat/auth/AO-702-otp-resend` vs `DEV`

## Setup

- App: mobile dev build, Login screen
- Account: QA account "otp-tester" (password in 1Password, vault "QA")
- Flags: remote config `otp_resend_v2` = true

## Behaviors

| ID  | Behavior | Sources | Coverage | Test |
| --- | -------- | ------- | -------- | ---- |
| B-1 | "Resend code" is disabled for 60 seconds after a code is sent | `src/auth/OtpScreen.tsx:22` | none | TC-1 |
| B-2 | After 3 resends the screen shows a 15 minute lockout | `src/auth/OtpScreen.tsx:40` | partial: `lockout.test.ts` | TC-2 |
| B-3 | Android back button on the OTP screen goes back to Login | `src/auth/OtpScreen.android.tsx:8` | none | TC-3 |
| B-4 | A failed resend shows "Could not send code" | `src/auth/OtpScreen.tsx:55` | none | TC-6 |
| B-5 | The code from the SMS fills the field by itself | `src/auth/useSmsAutofill.ts:12` | none | TC-5 |

## Test Cases

### TC-1 - Resend cooldown

- Behaviors: B-1
- Platform: ios, android
- Steps:
  1. Enter the phone number of "otp-tester" and tap "Send code"
  2. Look at "Resend code"
- Expected: "Resend code" is disabled and shows "Resend in 60s", counting down.
- ios:
  - Mode: agent
  - Status: pass
  - Recording: TC-1/TC-1-ios.mp4
  - Note: Countdown went from 60s to 0s, then the button was enabled.
- android:
  - Mode: agent
  - Status: fail
  - Recording: TC-1/TC-1-android.mp4
  - Note: Countdown froze at 41s.

### TC-2 - Lockout after 3 resends

- Behaviors: B-2
- Platform: ios, android
- Preconditions: after TC-1
- Steps:
  1. Tap "Resend code" each time it is enabled, 3 times
- Expected: "Too many attempts. Try again in 15:00" shows. "Resend code" is hidden.
- Outdated: lockout changed from 10 to 15 minutes
- ios:
  - Mode: agent
  - Status: outdated
  - Recording: TC-2/TC-2-ios.mp4
  - Note: Lockout text showed 10:00.
- android:
  - Mode: agent
  - Status: outdated
  - Recording: TC-2/TC-2-android.mp4
  - Note: Lockout text showed 10:00.

### TC-3 - Back button on Android

- Behaviors: B-3
- Platform: android
- Steps:
  1. Tap "Send code"
  2. Press the system back button
- Expected: the Login screen shows.

### TC-4 - Resend by voice call

- Platform: ios, android
- Steps:
  1. Tap "Call me instead"
- Expected: "Calling you now" shows.
- Removed: voice call was dropped from the ticket

### TC-5 - SMS autofill

- Behaviors: B-5
- Platform: ios, android
- Steps:
  1. Tap "Send code" with a real SIM phone number
  2. Wait for the SMS to arrive on the phone
- Expected: the 6-digit code from the SMS fills the field.

### TC-6 - Failed resend

- Behaviors: B-4
- Platform: ios, android
- Preconditions: the mock server returns 500 for `POST /otp/resend` (`yarn mock:otp-fail`)
- Steps:
  1. Tap "Send code"
  2. Wait until "Resend code" is enabled and tap it
- Expected: "Could not send code" shows under the field.
EOF
fi

if [ "$KIND" = "other-format" ]; then
  mkdir -p spec/testcases/sentence-search
  cat > spec/testcases/sentence-search/cases.md <<'EOF'
# Sentence search

## Setup

- Account: QA account "jp-learner"
- Data: the N5 deck is downloaded

## SS1 — Search a common word shows ranked results

- Status: active
- Driver: agent
- Targets: ios, android
- Needs: signed in, on the Search tab
- Steps:
  1. Type 食べる in the search field
  2. Tap "Search"
- Expect:
  - The first result contains 食べる
  - No empty state
- Server check: `GET /v2/sentences?q=食べる` returns 200

## SS2 — Search by handwriting

- Status: active
- Driver: human
- Targets: ios, android
- Needs: on the Search tab
- Steps:
  1. Draw 食 on the handwriting pad
- Expect:
  - 食 shows as the first suggestion

## SS3 — Spotlight search opens a sentence

- Status: active
- Driver: agent
- Targets: ios
- Needs: app installed, signed in
- Steps:
  1. Pull down on the home screen and type 食べる
  2. Tap the AQX result
- Expect:
  - The sentence screen for 食べる opens

## SS4 — Search history

- Status: inactive
- Driver: agent
- Targets: ios, android
- Needs: on the Search tab
- Steps:
  1. Tap the search field
- Expect:
  - The last 5 searches show
EOF
fi

if [ "$KIND" = "web-transfer" ]; then
  printf '.evidence/\n' >> .gitignore
  mkdir -p web specs/testcases
  cat > web/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Transfer</title></head>
<body>
  <h1>Transfer</h1>
  <p id="balance">Balance: 100 USD</p>
  <form id="form">
    <label for="amount">Amount (USD)</label>
    <input id="amount" inputmode="decimal">
    <button type="submit">Send</button>
  </form>
  <p id="error" role="alert"></p>
  <p id="done" role="status"></p>
  <script>
    const BALANCE = 100;
    document.getElementById('form').addEventListener('submit', (e) => {
      e.preventDefault();
      const amount = Number(document.getElementById('amount').value);
      const error = document.getElementById('error');
      const done = document.getElementById('done');
      error.textContent = '';
      done.textContent = '';
      if (!(amount > 0)) { error.textContent = 'Enter an amount'; return; }
      if (amount < 10) { error.textContent = 'Minimum is 10 USD'; return; }
      if (amount > BALANCE + 50) { error.textContent = 'Amount exceeds balance'; return; }
      done.textContent = `Sent ${amount} USD`;
    });
  </script>
</body>
</html>
EOF
  cat > specs/testcases/AO-801.md <<EOF
# AO-801 - Transfer form

Source: AO-801 ticket text from the user, diff \`feat/AO-801-transfer\` vs \`DEV\`

## Setup

- App: web, start with \`python3 -m http.server $PORT -d web\` from the repo root, then open http://localhost:$PORT/
- Data: balance is 100 USD (fixed in the page)

## Behaviors

| ID  | Behavior | Sources | Coverage | Test |
| --- | -------- | ------- | -------- | ---- |
| B-1 | An amount under 10 USD shows "Minimum is 10 USD" | AC-1; \`web/index.html:24\` | none | TC-1 |
| B-2 | An amount over the balance shows "Amount exceeds balance" | AC-2; \`web/index.html:25\` | none | TC-2 |
| B-3 | A valid amount shows "Sent <amount> USD" | AC-3; \`web/index.html:26\` | none | TC-3 |
| B-4 | Face ID confirms transfers over 50 USD on iOS | AC-4; \`ios/Transfer/FaceID.swift:12\` | none | TC-4 |

## Test Cases

### TC-1 - Amount under the minimum

- Behaviors: B-1
- Platform: web
- Steps:
  1. Enter \`5\` in "Amount (USD)"
  2. Click "Send"
- Expected: "Minimum is 10 USD" shows. No "Sent" message shows.

### TC-2 - Amount over the balance

- Behaviors: B-2
- Platform: web
- Steps:
  1. Enter \`120\` in "Amount (USD)"
  2. Click "Send"
- Expected: "Amount exceeds balance" shows. No "Sent" message shows.

### TC-3 - Valid transfer

- Behaviors: B-3
- Platform: web
- Steps:
  1. Enter \`25\` in "Amount (USD)"
  2. Click "Send"
- Expected: "Sent 25 USD" shows.

### TC-4 - Face ID for large transfers

- Behaviors: B-4
- Platform: ios
- Steps:
  1. Enter \`60\` in "Amount"
  2. Tap "Send"
- Expected: the Face ID prompt shows.
EOF
fi

git add -A && git commit -qm "init"
echo "$DEST" >&2
