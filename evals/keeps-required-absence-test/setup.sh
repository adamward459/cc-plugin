set -e
mkdir -p src test
echo '{ "type": "module" }' > package.json
cat > src/profile.js <<'JS'
export function publicProfile(user) {
  return { name: user.name, avatarUrl: user.avatarUrl, email: user.email };
}
JS
cat > test/profile.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { publicProfile } from "../src/profile.js";

const user = { name: "Ana", avatarUrl: "/a.png", email: "ana@example.com", passwordHash: "x" };

test("shows name, avatar, and email", () => {
  assert.deepEqual(publicProfile(user), {
    name: "Ana",
    avatarUrl: "/a.png",
    email: "ana@example.com",
  });
});
JS
