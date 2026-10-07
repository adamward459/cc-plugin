#!/bin/bash
set -e
# Usage: make-repo.sh <web-withdraw|mobile-otp|web-withdraw-update|mobile-otp-update> <dest>
KIND="$1"
DEST="$2"
[ -n "$KIND" ] && [ -n "$DEST" ] || { echo "Usage: make-repo.sh <kind> <dest>" >&2; exit 1; }
rm -rf "$DEST" && mkdir -p "$DEST" && cd "$DEST"
git init -q -b DEV
git config user.email qa@example.com
git config user.name QA
commit() { git add -A && git commit -qm "$1"; }

if [ "$KIND" = "web-withdraw" ] || [ "$KIND" = "web-withdraw-update" ]; then
  mkdir -p src/withdraw
  cat > package.json <<'EOF'
{ "name": "aqx-pay-web", "private": true, "scripts": { "dev": "next dev", "test": "jest" },
  "dependencies": { "next": "14.2.0", "react": "18.2.0" },
  "devDependencies": { "jest": "29.7.0", "@testing-library/react": "14.2.0" } }
EOF
  cat > src/withdraw/WithdrawForm.tsx <<'EOF'
import { useState } from 'react';

export function WithdrawForm() {
  const [amount, setAmount] = useState('');
  return (
    <form>
      <label htmlFor="amount">Amount</label>
      <input id="amount" value={amount} onChange={(e) => setAmount(e.target.value)} />
      <button type="submit">Withdraw</button>
    </form>
  );
}
EOF
  commit "init withdraw form"
  git checkout -qb feat/withdraw/AO-618-fiat-withdrawal-form
  cat > src/withdraw/validateAmount.ts <<'EOF'
export const MIN_WITHDRAW_USD = 10;

export function validateAmount(amount: number, balance: number): string | null {
  if (!Number.isFinite(amount) || amount <= 0) return 'Enter an amount';
  if (amount < MIN_WITHDRAW_USD) return `Minimum withdrawal is ${MIN_WITHDRAW_USD} USD`;
  if (amount > balance) return 'Amount exceeds available balance';
  return null;
}
EOF
  cat > src/withdraw/fee.ts <<'EOF'
export function withdrawFee(amount: number): number {
  return Math.max(amount * 0.01, 2);
}
EOF
  cat > src/withdraw/WithdrawForm.tsx <<'EOF'
import { useState } from 'react';
import { useUser } from '../auth/useUser';
import { useBankAccounts } from '../bank/useBankAccounts';
import { useBalance } from '../wallet/useBalance';
import { toast } from '../ui/toast';
import { validateAmount } from './validateAmount';
import { withdrawFee } from './fee';
import { ConfirmWithdrawal } from './ConfirmWithdrawal';

export function WithdrawForm() {
  const user = useUser();
  const { accounts } = useBankAccounts();
  const { usd } = useBalance();
  const [amount, setAmount] = useState('');
  const [accountId, setAccountId] = useState(accounts[0]?.id ?? '');
  const [error, setError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);

  if (process.env.NEXT_PUBLIC_FIAT_WITHDRAW_V2 !== 'true') return null;
  if (user.kycStatus !== 'APPROVED') {
    return <p role="alert">Complete KYC to withdraw</p>;
  }
  if (accounts.length === 0) {
    return <a href="/settings/bank-accounts">Add a bank account to withdraw</a>;
  }

  const value = Number(amount);
  const onContinue = (e: React.FormEvent) => {
    e.preventDefault();
    const message = validateAmount(value, usd);
    setError(message);
    if (!message) setConfirming(true);
  };

  const onConfirm = async () => {
    const res = await fetch('/api/withdrawals', {
      method: 'POST',
      body: JSON.stringify({ amount: value, bankAccountId: accountId, currency: 'USD' }),
    });
    if (res.status === 422) {
      toast.error('Daily limit exceeded');
      return;
    }
    toast.success('Withdrawal submitted');
  };

  if (confirming) {
    return (
      <ConfirmWithdrawal
        amount={value}
        fee={withdrawFee(value)}
        account={accounts.find((a) => a.id === accountId)!}
        onBack={() => setConfirming(false)}
        onConfirm={onConfirm}
      />
    );
  }

  return (
    <form onSubmit={onContinue}>
      <label htmlFor="bank">Bank account</label>
      <select id="bank" value={accountId} onChange={(e) => setAccountId(e.target.value)}>
        {accounts.map((a) => (
          <option key={a.id} value={a.id}>{a.bankName} ••••{a.last4}</option>
        ))}
      </select>
      <label htmlFor="amount">Amount (USD)</label>
      <input id="amount" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} />
      {error && <p className="field-error">{error}</p>}
      <p>Available: {usd.toFixed(2)} USD</p>
      {value > 0 && <p>Fee: {withdrawFee(value).toFixed(2)} USD</p>}
      <button type="submit">Continue</button>
    </form>
  );
}
EOF
  cat > src/withdraw/ConfirmWithdrawal.tsx <<'EOF'
type Props = {
  amount: number;
  fee: number;
  account: { bankName: string; last4: string };
  onBack: () => void;
  onConfirm: () => void;
};

export function ConfirmWithdrawal({ amount, fee, account, onBack, onConfirm }: Props) {
  return (
    <section>
      <h2>Confirm withdrawal</h2>
      <p>To: {account.bankName} ••••{account.last4}</p>
      <p>Amount: {amount.toFixed(2)} USD</p>
      <p>Fee: {fee.toFixed(2)} USD</p>
      <p>You receive: {(amount - fee).toFixed(2)} USD</p>
      <button onClick={onBack}>Back</button>
      <button onClick={onConfirm}>Confirm</button>
    </section>
  );
}
EOF
  mkdir -p src/withdraw/__tests__
  cat > src/withdraw/__tests__/validateAmount.test.ts <<'EOF'
import { validateAmount } from '../validateAmount';

describe('validateAmount', () => {
  it('rejects amounts below the minimum', () => {
    expect(validateAmount(5, 100)).toBe('Minimum withdrawal is 10 USD');
  });
  it('rejects amounts above the balance', () => {
    expect(validateAmount(150, 100)).toBe('Amount exceeds available balance');
  });
  it('accepts a valid amount', () => {
    expect(validateAmount(50, 100)).toBeNull();
  });
});
EOF
  cat > src/withdraw/__tests__/fee.test.ts <<'EOF'
import { withdrawFee } from '../fee';

describe('withdrawFee', () => {
  it('charges 1% of the amount', () => expect(withdrawFee(500)).toBe(5));
  it('charges at least 2 USD', () => expect(withdrawFee(50)).toBe(2));
});
EOF
  cat > src/withdraw/__tests__/WithdrawForm.test.tsx <<'EOF'
import { render, screen } from '@testing-library/react';
import { WithdrawForm } from '../WithdrawForm';

jest.mock('../../auth/useUser', () => ({ useUser: () => ({ kycStatus: 'PENDING' }) }));
jest.mock('../../bank/useBankAccounts', () => ({ useBankAccounts: () => ({ accounts: [] }) }));
jest.mock('../../wallet/useBalance', () => ({ useBalance: () => ({ usd: 0 }) }));

describe('WithdrawForm', () => {
  beforeEach(() => { process.env.NEXT_PUBLIC_FIAT_WITHDRAW_V2 = 'true'; });

  it('blocks users without approved KYC', () => {
    render(<WithdrawForm />);
    expect(screen.getByRole('alert')).toHaveTextContent('Complete KYC to withdraw');
  });
});
EOF
  commit "feat(withdraw): AO-618 - fiat withdrawal form with bank account, fee and confirm step"

  if [ "$KIND" = "web-withdraw-update" ]; then
    mkdir -p specs/testcases
    cat > specs/testcases/AO-618.md <<'EOF'
# AO-618 - Fiat withdrawal form

Source: Jira AO-618, diff `feat/withdraw/AO-618-fiat-withdrawal-form` vs `DEV`

## Setup

- App: web DEV, http://localhost:3000/withdraw
- Flags: `NEXT_PUBLIC_FIAT_WITHDRAW_V2=true` in `.env.local`
- Account: QA trader account with KYC approved (1Password "QA trader")
- Data: at least one saved bank account, USD balance of at least 100 USD

## Test Cases

### TC-1 - AC-2: Amount below the minimum is rejected

- Platform: web
- Steps:
  1. Enter `5` in "Amount (USD)"
  2. Click "Continue"
- Expected: "Minimum withdrawal is 10 USD" shows under the amount field. The confirm step does not open.
- Mode: agent
- Status: pass
- Recording: TC-1/recording.webm
- Note: Typed 5 and clicked Continue. "Minimum withdrawal is 10 USD" appeared in red under the field. The page stayed on the form.

### TC-2 - AC-6: Confirm step shows the summary

- Platform: web
- Steps:
  1. Select a bank account
  2. Enter `50` in "Amount (USD)"
  3. Click "Continue"
- Expected: "Confirm withdrawal" shows the bank, Amount 50.00 USD, Fee 2.00 USD, You receive 48.00 USD.
- Mode: agent
- Status: pass
- Recording: TC-2/recording.webm
- Note: Confirm screen showed "To: DBS ••••1234", Amount 50.00 USD, Fee 2.00 USD, You receive 48.00 USD.

### TC-3 - EDGE: Daily limit error from the API

- Platform: web
- Steps:
  1. Enter `5000` in "Amount (USD)" with a balance above 5000
  2. Click "Continue", then "Confirm"
- Expected: Toast "Daily limit exceeded". No success toast.

## Covered by automation

- AC-5: KYC not approved — `src/withdraw/__tests__/WithdrawForm.test.tsx` › "blocks users without approved KYC"
EOF
    commit "docs: AO-618 test cases"
    cat > src/withdraw/validateAmount.ts <<'EOF'
export const MIN_WITHDRAW_USD = 20;

export function validateAmount(amount: number, balance: number): string | null {
  if (!Number.isFinite(amount) || amount <= 0) return 'Enter an amount';
  if (amount < MIN_WITHDRAW_USD) return `Minimum withdrawal is ${MIN_WITHDRAW_USD} USD`;
  if (amount > balance) return 'Amount exceeds available balance';
  return null;
}
EOF
    sed -i '' 's/validateAmount(5, 100)).toBe(.Minimum withdrawal is 10 USD.)/validateAmount(15, 100)).toBe("Minimum withdrawal is 20 USD")/' src/withdraw/__tests__/validateAmount.test.ts
    perl -0pi -e 's|(      <p>Available: \{usd.toFixed\(2\)\} USD</p>\n)|$1      <button type="button" onClick={() => setAmount((usd - withdrawFee(usd)).toFixed(2))}>Withdraw all</button>\n|' src/withdraw/WithdrawForm.tsx
    commit "feat(withdraw): AO-618 - add Withdraw all, raise minimum to 20 USD"
  fi
fi

if [ "$KIND" = "mobile-otp" ] || [ "$KIND" = "mobile-otp-update" ]; then
  mkdir -p packages/mobile-app/src/screens packages/mobile-app/src/utils packages/web-admin
  cat > package.json <<'EOF'
{ "name": "aqx-pay-otc-app", "private": true, "workspaces": ["packages/*"] }
EOF
  cat > packages/mobile-app/package.json <<'EOF'
{ "name": "mobile-app", "dependencies": { "expo": "51.0.0", "react-native": "0.74.0" },
  "scripts": { "ios": "expo run:ios", "android": "expo run:android", "test": "jest" } }
EOF
  cat > packages/mobile-app/src/screens/OtpScreen.tsx <<'EOF'
import { useState } from 'react';
import { Text, TextInput, Pressable } from 'react-native';
import { api } from '../api';

export function OtpScreen({ phone }: { phone: string }) {
  const [code, setCode] = useState('');
  return (
    <>
      <Text>Enter the code sent to {phone}</Text>
      <TextInput value={code} onChangeText={setCode} keyboardType="number-pad" maxLength={6} />
      <Pressable onPress={() => api.resendOtp(phone)}><Text>Resend code</Text></Pressable>
    </>
  );
}
EOF
  commit "init otp screen"
  git checkout -qb fix/AO-702-otp-resend-timer
  cat > packages/mobile-app/src/utils/formatCountdown.ts <<'EOF'
export function formatCountdown(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}
EOF
  cat > packages/mobile-app/src/utils/formatCountdown.test.ts <<'EOF'
import { formatCountdown } from './formatCountdown';

it('formats seconds as m:ss', () => {
  expect(formatCountdown(59)).toBe('0:59');
  expect(formatCountdown(900)).toBe('15:00');
});
EOF
  cat > packages/mobile-app/src/screens/OtpScreen.tsx <<'EOF'
import { useEffect, useState } from 'react';
import { AppState, Text, TextInput, Pressable } from 'react-native';
import { api } from '../api';
import { useRemoteConfig } from '../config/useRemoteConfig';
import { formatCountdown } from '../utils/formatCountdown';

const RESEND_COOLDOWN_S = 60;
const MAX_RESENDS = 3;
const LOCKOUT_S = 15 * 60;

export function OtpScreen({ phone }: { phone: string }) {
  const { otp_resend_v2 } = useRemoteConfig();
  const [code, setCode] = useState('');
  const [cooldown, setCooldown] = useState(RESEND_COOLDOWN_S);
  const [resends, setResends] = useState(0);
  const [lockedUntil, setLockedUntil] = useState<number | null>(null);

  useEffect(() => {
    const id = setInterval(() => setCooldown((c) => Math.max(c - 1, 0)), 1000);
    return () => clearInterval(id);
  }, []);

  // Timers pause in background; recompute from wall clock when the app returns.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active' && lockedUntil) {
        setCooldown(Math.max(Math.ceil((lockedUntil - Date.now()) / 1000), 0));
      }
    });
    return () => sub.remove();
  }, [lockedUntil]);

  const onResend = async () => {
    if (resends + 1 >= MAX_RESENDS) {
      setLockedUntil(Date.now() + LOCKOUT_S * 1000);
      setCooldown(LOCKOUT_S);
    } else {
      setCooldown(RESEND_COOLDOWN_S);
    }
    setResends((n) => n + 1);
    try {
      await api.resendOtp(phone);
    } catch {
      setCooldown(0);
    }
  };

  const locked = lockedUntil !== null && cooldown > 0;

  return (
    <>
      <Text>Enter the code sent to {phone}</Text>
      <TextInput value={code} onChangeText={setCode} keyboardType="number-pad" maxLength={6} />
      {!otp_resend_v2 ? (
        <Pressable onPress={() => api.resendOtp(phone)}><Text>Resend code</Text></Pressable>
      ) : locked ? (
        <Text>Too many attempts. Try again in {formatCountdown(cooldown)}</Text>
      ) : cooldown > 0 ? (
        <Text>Resend code in {formatCountdown(cooldown)}</Text>
      ) : (
        <Pressable onPress={onResend}><Text>Resend code</Text></Pressable>
      )}
    </>
  );
}
EOF
  commit "fix(otp): AO-702 - resend cooldown and lockout"

  if [ "$KIND" = "mobile-otp-update" ]; then
    mkdir -p specs/testcases
    cat > specs/testcases/AO-702.md <<'EOF'
# AO-702 - OTP resend cooldown and lockout

Source: diff `fix/AO-702-otp-resend-timer` vs `DEV`

## Setup

- App: `mobile-app` on an iOS and an Android simulator (`expo run:ios`, `expo run:android`)
- Account: QA OTP test number (1Password "QA OTP phone")
- Flags: remote config `otp_resend_v2` on

## Behaviors

| ID  | Behavior | Sources | Coverage | Test |
| --- | -------- | ------- | -------- | ---- |
| B-1 | Opening the OTP screen hides "Resend code" and shows "Resend code in 1:00" counting down to 0 | `packages/mobile-app/src/screens/OtpScreen.tsx:7`, `packages/mobile-app/src/screens/OtpScreen.tsx:58-59` | partial: `formatCountdown.test.ts` › "formats seconds as m:ss" checks the helper, not the screen | TC-1 |
| B-2 | The 3rd resend locks the screen: "Too many attempts. Try again in 15:00" | `packages/mobile-app/src/screens/OtpScreen.tsx:34-36`, `packages/mobile-app/src/screens/OtpScreen.tsx:57` | none | TC-2 |
| B-3 | A failed resend shows the "Resend code" button again at once | `packages/mobile-app/src/screens/OtpScreen.tsx:42-45` | none | TC-3 |

## Test Cases

### TC-1 - The cooldown counts down from 1:00

- Behaviors: B-1
- Platform: ios, android
- Steps:
  1. Submit the QA phone number and reach the OTP screen
  2. Wait until the countdown runs out
- Expected: "Resend code in 1:00" shows and counts down to 0. At 0 a tappable "Resend code" button replaces it.
- ios:
  - Mode: agent
  - Status: pass
  - Recording: TC-1/ios.mp4
  - Note: Countdown went from 1:00 to 0:00 in 60 seconds, then "Resend code" appeared.
- android:
  - Mode: agent
  - Status: fail
  - Recording: TC-1/android.mp4
  - Note: Countdown froze at 0:41 after the keyboard closed.

### TC-2 - The third resend locks the screen for 15 minutes

- Behaviors: B-2
- Platform: ios, android
- Preconditions: two resends already done, countdown at 0
- Steps:
  1. Tap "Resend code"
- Expected: "Too many attempts. Try again in 15:00" shows and counts down. No "Resend code" button.
- ios:
  - Mode: agent
  - Status: pass
  - Recording: TC-2/ios.mp4
  - Note: Lockout text showed 15:00 and counted down.
- android:
  - Mode: agent
  - Status: pass
  - Recording: TC-2/android.mp4
  - Note: Same as iOS on a Pixel 7 emulator.

### TC-3 - A failed resend brings the button back

- Behaviors: B-3
- Platform: ios, android
- Preconditions: countdown at 0, airplane mode on
- Steps:
  1. Tap "Resend code"
- Expected: "Resend code" shows again at once.
EOF
    commit "docs: AO-702 test cases"
    sed -i '' 's/const RESEND_COOLDOWN_S = 60;/const RESEND_COOLDOWN_S = 30;/' packages/mobile-app/src/screens/OtpScreen.tsx
    commit "fix(otp): AO-702 - shorten resend cooldown to 30s"
  fi
fi
echo "$DEST" >&2
