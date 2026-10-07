#!/bin/bash
set -e
# Usage: make-repo.sh <github|gitlab|other> <dest>
KIND="$1"
DEST="$2"
[ -n "$KIND" ] && [ -n "$DEST" ] || { echo "Usage: make-repo.sh <kind> <dest>" >&2; exit 1; }
rm -rf "$DEST" && mkdir -p "$DEST" && cd "$DEST"
git init -q -b feat/evidence
git config user.email qa@example.com
git config user.name QA
printf 'node_modules/\n.evidence/\n' > .gitignore
echo '{ "name": "aqx", "private": true }' > package.json

blob() { mkdir -p "$(dirname "$1")"; head -c "$2" /dev/urandom > "$1"; }

note() { # note <path> <id> <target> <title> <result> <video> [extra]
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
# $2 — $3 — $4

- Result: $5
- Driven by: agent (argent)
- Build: dev · Device: iPhone 16 (sim)
- Account: otp-tester
- Date: 2026-10-06
- Video: $6

## Checks

- [x] The screen shows
$7
EOF
}

SERVER_CHECK='
## Server check

POST /otp/resend → 429. Lockout row exists for otp-tester with 15 min expiry.'

if [ "$KIND" = "github" ]; then
  git remote add origin git@github.com:acme/aqx-mobile.git
  mkdir -p specs/testcases
  cat > specs/testcases/AO-702.md <<'EOF'
# AO-702 - OTP resend

## Test Cases

### TC-1 - Lockout after 3 resends

- Platform: ios, android
- Steps:
  1. Tap "Resend code" 3 times
- Expected: "Too many attempts. Try again in 15:00" shows.
- Server check: `POST /otp/resend` returns 429

### TC-2 - Resend cooldown

- Platform: ios
- Steps:
  1. Tap "Send code"
- Expected: "Resend in 60s" shows, counting down.

### TC-3 - Back button on Android

- Platform: android
- Steps:
  1. Press the system back button
- Expected: the Login screen shows.

### TC-4 - Resend by voice call

- Platform: ios, android
- Steps:
  1. Tap "Call me instead"
- Expected: "Calling you now" shows.
- Removed: voice call was dropped from the ticket
EOF
  E=.evidence/AO-702
  note $E/TC-1/TC-1-ios.md TC-1 iOS "Lockout after 3 resends" pass TC-1-ios.mp4 "$SERVER_CHECK"
  blob $E/TC-1/TC-1-ios.mp4 300000
  blob $E/TC-1/TC-1-ios-1-otp-screen.png 41000
  blob $E/TC-1/TC-1-ios-2-first-resend.png 42000
  blob $E/TC-1/TC-1-ios-3-third-resend.png 43000
  blob $E/TC-1/TC-1-ios-4-lockout-banner.png 44000
  printf 'POST /otp/resend\nAuthorization: Bearer sk_live_SECRET123\n429 Too Many Requests\n' > $E/TC-1/TC-1-ios-server.txt
  note $E/TC-1/TC-1-android.md TC-1 Android "Lockout after 3 resends" pass TC-1-android.mp4
  blob $E/TC-1/TC-1-android.mp4 310000
  note $E/TC-2/TC-2-ios.md TC-2 iOS "Resend cooldown" fail TC-2-ios.mp4 '
## What I saw

Tapped "Send code". Expected "Resend in 60s" counting down. The label stayed at "Resend in 60s" and never counted down.'
  blob $E/TC-2/TC-2-ios.mp4 320000
  blob $E/TC-2/TC-2-ios-1-cooldown-frozen.png 45000
fi

if [ "$KIND" = "gitlab" ]; then
  git remote add origin https://gitlab.acme.dev/mobile/aqx.git
  mkdir -p spec/testcases/sentence-search
  cat > spec/testcases/sentence-search/cases.md <<'EOF'
# Sentence search

## SS1 — Search a common word shows ranked results

- Status: active
- Driver: agent
- Targets: web, ios
- Steps:
  1. Type 食べる in the search field
  2. Tap "Search"
- Expect:
  - The first result contains 食べる

## SS2 — Search history

- Status: inactive
- Driver: agent
- Targets: ios, android
- Steps:
  1. Tap the search field
- Expect:
  - The last 5 searches show
EOF
  E=.evidence/sentence-search
  note $E/SS1/SS1-web.md SS1 Web "Search a common word shows ranked results" pass SS1-web.mp4
  blob $E/SS1/SS1-web.mp4 250000
  note $E/SS1/SS1-ios.md SS1 iOS "Search a common word shows ranked results" pass SS1-ios.mp4
  blob $E/SS1/SS1-ios.mp4 260000
  blob $E/SS1/SS1-ios-1-search-tab.png 30000
  blob $E/SS1/SS1-ios-2-ranked-results.png 31000
fi

if [ "$KIND" = "other" ]; then
  git remote add origin git@bitbucket.org:acme/transfer-web.git
  mkdir -p specs/testcases
  cat > specs/testcases/AO-801.md <<'EOF'
# AO-801 - Transfer form

## Test Cases

### TC-1 - Amount under the minimum

- Platform: web
- Steps:
  1. Enter `5` and click "Send"
- Expected: "Minimum is 10 USD" shows.

### TC-2 - Amount over the balance

- Platform: web
- Steps:
  1. Enter `120` and click "Send"
- Expected: "Amount exceeds balance" shows.

### TC-3 - Valid transfer

- Platform: web
- Steps:
  1. Enter `25` and click "Send"
- Expected: "Sent 25 USD" shows.

### TC-4 - Face ID for large transfers

- Platform: ios
- Steps:
  1. Enter `60` and tap "Send"
- Expected: the Face ID prompt shows.
EOF
  E=.evidence/AO-801
  note $E/TC-1/TC-1-web.md TC-1 Web "Amount under the minimum" pass TC-1-web.mp4
  blob $E/TC-1/TC-1-web.mp4 200000
  note $E/TC-2/TC-2-web.md TC-2 Web "Amount over the balance" fail TC-2-web.mp4 '
## What I saw

Entered 120 and clicked "Send". Expected "Amount exceeds balance". The page showed "Sent 120 USD".'
  blob $E/TC-2/TC-2-web.mp4 210000
  note $E/TC-3/TC-3-web.md TC-3 Web "Valid transfer" pass TC-3-web.mp4
  blob $E/TC-3/TC-3-web.mp4 220000
fi

git add -A && git commit -qm "init"
echo "$DEST" >&2
